/**
 * DAKAR BUS — MOTEUR COMMUN DE DÉPARTS ET D'ESTIMATION (v1)
 * ==========================================================================
 * Répond à : « Quel transport puis-je prendre maintenant et quand puis-je
 * partir ? » — y compris quand aucun horaire précis n'existe.
 *
 * HIÉRARCHIE IMPOSÉE (ordre strict par défaut)
 *   1. horaire précis fiable .......... SCHEDULED
 *   2. sinon fréquence fiable ......... ESTIMATED   (une FENÊTRE, jamais une heure)
 *   3. sinon donnée véhicule réelle ... REAL_TIME   (observation exigée)
 *   4. sinon .......................... UNKNOWN
 *
 * RÈGLES ABSOLUES CODÉES ICI (et vérifiées par tests/departure-engine.test.js)
 *   • une estimation n'est jamais présentée comme un horaire officiel ;
 *   • une fréquence n'est jamais présentée comme du temps réel ;
 *   • le GPS de l'utilisateur n'est jamais un véhicule ;
 *   • aucune heure précise n'est inventée : une estimation est une fenêtre ;
 *   • aucune donnée HISTORICAL / UNKNOWN ne produit d'estimation actuelle ;
 *   • une source COMMUNITY n'est jamais « officielle » ;
 *   • aucune donnée simulée n'est acceptée (véhicule, retard, position).
 *
 * Aucune donnée n'est embarquée dans ce fichier : le référentiel de fréquences
 * vit dans data/transit/departure-frequencies.json et doit être fourni par
 * l'appelant. Sans données → UNKNOWN (échec fermé, jamais d'invention).
 *
 * Fonctionne en navigateur (`window.DakarDepartureEngine`) et en Node
 * (`require('.../engine/departure-engine.js')`).
 */
(function (root, factory) {
  'use strict';
  const api = factory();
  if (typeof module === 'object' && module && module.exports) module.exports = api;
  if (root) root.DakarDepartureEngine = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const ENGINE_VERSION = '1.0.1';

  /** Statuts autorisés — strictement quatre, aucun statut « LIVE » parallèle. */
  const STATUS = Object.freeze({
    SCHEDULED: 'SCHEDULED',
    ESTIMATED: 'ESTIMATED',
    REAL_TIME: 'REAL_TIME',
    UNKNOWN: 'UNKNOWN',
  });
  const STATUS_VALUES = Object.freeze(Object.values(STATUS));

  /**
   * Vocabulaire d'AFFICHAGE unique, miroir de la source unique côté Flutter
   * (`ScheduleStatus.displayLabel()` et `ReliabilityLabel.scheduleUnavailable`).
   * Le statut circule (SCHEDULED/ESTIMATED/REAL_TIME/UNKNOWN) ; ces libellés ne
   * sont produits qu'ici et ne sont jamais redéfinis par une interface.
   */
  const LABELS = Object.freeze({
    SCHEDULED: 'Horaire théorique',
    ESTIMATED: 'Estimation',
    REAL_TIME: 'Temps réel',
    UNKNOWN: 'Horaire indisponible',
  });

  /**
   * Statut historique de l'application (`DataStatus.live` côté Flutter) : il
   * n'est ni supprimé ni réutilisé. [legacyStatusToStatus] le ramène dans les
   * quatre statuts autorisés — `live` devient UNKNOWN tant qu'aucune
   * observation réelle ne l'accompagne.
   */
  function legacyStatusToStatus(legacy) {
    switch (String(legacy || '').toUpperCase()) {
      case 'LIVE':
        return STATUS.UNKNOWN;
      case 'SCHEDULED':
        return STATUS.SCHEDULED;
      case 'ESTIMATED':
        return STATUS.ESTIMATED;
      case 'REAL_TIME':
        return STATUS.REAL_TIME;
      default:
        return STATUS.UNKNOWN;
    }
  }

  const SOURCE_TYPES = Object.freeze({
    OFFICIAL: 'OFFICIAL',
    INSTITUTIONAL: 'INSTITUTIONAL',
    OPEN_DATA: 'OPEN_DATA',
    COMMUNITY: 'COMMUNITY',
    HISTORICAL: 'HISTORICAL',
    UNKNOWN: 'UNKNOWN',
  });

  /**
   * Politique de source (cf. §16).
   *   usable        : la donnée peut servir à une estimation/affichage ;
   *   confidence    : confiance transmise dans DepartureEstimate.confidence ;
   *   official      : peut être qualifiée d'officielle à l'affichage.
   * COMMUNITY est utilisable seulement si l'appelant l'autorise explicitement
   * (`allowCommunity`) et n'est jamais officielle. HISTORICAL et UNKNOWN ne
   * produisent jamais de service actuel.
   */
  const SOURCE_POLICY = Object.freeze({
    OFFICIAL: { usable: true, confidence: 'high', official: true },
    INSTITUTIONAL: { usable: true, confidence: 'medium', official: true },
    OPEN_DATA: { usable: true, confidence: 'medium', official: false },
    COMMUNITY: { usable: false, confidence: 'low', official: false, optIn: true },
    HISTORICAL: { usable: false, confidence: 'none', official: false },
    UNKNOWN: { usable: false, confidence: 'none', official: false },
  });

  const FREQUENCY_STATUS = Object.freeze({
    ACTIVE: 'ACTIVE',
    HISTORICAL: 'HISTORICAL',
    PENDING_VERIFICATION: 'PENDING_VERIFICATION',
  });

  const DAY_TYPES = Object.freeze({
    MONDAY: 'MONDAY',
    TUESDAY: 'TUESDAY',
    WEDNESDAY: 'WEDNESDAY',
    THURSDAY: 'THURSDAY',
    FRIDAY: 'FRIDAY',
    SATURDAY: 'SATURDAY',
    SUNDAY: 'SUNDAY',
    HOLIDAY: 'HOLIDAY',
  });
  const DAY_NAMES = Object.freeze([
    DAY_TYPES.SUNDAY, DAY_TYPES.MONDAY, DAY_TYPES.TUESDAY, DAY_TYPES.WEDNESDAY,
    DAY_TYPES.THURSDAY, DAY_TYPES.FRIDAY, DAY_TYPES.SATURDAY,
  ]);

  /** Motifs machine — jamais affichés tels quels. */
  const REASONS = Object.freeze({
    SCHEDULED_TIMETABLE: 'SCHEDULED_TIMETABLE',
    FREQUENCY_ACTIVE: 'FREQUENCY_ACTIVE',
    FREQUENCY_BEFORE_SERVICE: 'FREQUENCY_BEFORE_SERVICE',
    OBSERVED_VEHICLE: 'OBSERVED_VEHICLE',
    NO_DATA: 'NO_DATA',
    NO_FREQUENCY_FOR_LINE: 'NO_FREQUENCY_FOR_LINE',
    NO_FREQUENCY_FOR_DAY: 'NO_FREQUENCY_FOR_DAY',
    FREQUENCY_NOT_CURRENT: 'FREQUENCY_NOT_CURRENT',
    SERVICE_ENDED: 'SERVICE_ENDED',
    SOURCE_NOT_USABLE: 'SOURCE_NOT_USABLE',
    NO_SCHEDULED_DEPARTURE_LEFT: 'NO_SCHEDULED_DEPARTURE_LEFT',
  });

  const MS_PER_MINUTE = 60000;
  /** Une observation plus vieille que ce délai n'est plus du temps réel. */
  const OBSERVATION_MAX_AGE_MINUTES = 30;

  // ------------------------------------------------------------------
  // Temps — Dakar = UTC+00:00 toute l'année, sans heure d'été
  // ------------------------------------------------------------------

  function pad2(n) { return String(n).padStart(2, '0'); }

  function isValidClock(value) {
    if (typeof value !== 'string' || !/^\d{2}:\d{2}$/.test(value)) return false;
    const [h, m] = value.split(':').map(Number);
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }

  function clockToMinutes(clock) {
    if (!isValidClock(clock)) return null;
    const [h, m] = clock.split(':').map(Number);
    return h * 60 + m;
  }

  /** 683 → "11:23" ; accepte une valeur supérieure à 24h (bornée au jour). */
  function minutesToClock(minutes) {
    if (!Number.isFinite(minutes)) return null;
    const m = ((Math.round(minutes) % 1440) + 1440) % 1440;
    return `${pad2(Math.floor(m / 60))}:${pad2(m % 60)}`;
  }

  /** "11:23" → "11h23" (affichage FR). */
  function clockToDisplay(clock) {
    if (!isValidClock(clock)) return null;
    const [h, m] = clock.split(':');
    return `${Number(h)}h${m}`;
  }

  function dateStringOf(date) {
    const d = date instanceof Date ? date : new Date(date);
    if (Number.isNaN(d.getTime())) return null;
    return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
  }

  function dayNameOf(date) {
    const d = date instanceof Date ? date : new Date(date);
    if (Number.isNaN(d.getTime())) return null;
    return DAY_NAMES[d.getUTCDay()];
  }

  /** Horodatage ISO local Dakar : "2026-09-25T11:43:00+00:00". */
  function isoLocalMinutes(dateStr, minutes) {
    const clock = minutesToClock(minutes);
    if (!dateStr || clock == null) return null;
    return `${dateStr}T${clock}:00+00:00`;
  }

  /** ISO ou {date, minutes} ou Date → repère interne. */
  function normalizeNow(now) {
    if (now && typeof now === 'object' && !(now instanceof Date) &&
        typeof now.minutes === 'number' && typeof now.date === 'string') {
      return {
        date: now.date,
        minutes: now.minutes,
        iso: isoLocalMinutes(now.date, now.minutes),
        dayName: dayNameOf(new Date(`${now.date}T00:00:00Z`)),
      };
    }
    const d = now instanceof Date ? now : new Date(now == null ? Date.now() : now);
    if (Number.isNaN(d.getTime())) return null;
    const minutes = d.getUTCHours() * 60 + d.getUTCMinutes();
    return { date: dateStringOf(d), minutes, iso: isoLocalMinutes(dateStringOf(d), minutes), dayName: dayNameOf(d) };
  }

  /**
   * Type de jour effectif. Les jours fériés ne sont appliqués que s'ils sont
   * explicitement déclarés (`holidays` = liste de dates "YYYY-MM-DD").
   * Aucun jour férié n'est deviné.
   */
  function dayTypeOf(now, holidays) {
    const ref = normalizeNow(now);
    if (!ref) return null;
    const list = Array.isArray(holidays) ? holidays : [];
    if (ref.date && list.includes(ref.date)) return DAY_TYPES.HOLIDAY;
    return ref.dayName;
  }

  // ------------------------------------------------------------------
  // Politique de source
  // ------------------------------------------------------------------

  function sourcePolicy(sourceType, options) {
    const key = String(sourceType || SOURCE_TYPES.UNKNOWN).toUpperCase();
    const policy = SOURCE_POLICY[key] || SOURCE_POLICY.UNKNOWN;
    const allowCommunity = !!(options && options.allowCommunity);
    const usable = policy.usable || (policy.optIn === true && allowCommunity);
    return {
      sourceType: SOURCE_POLICY[key] ? key : SOURCE_TYPES.UNKNOWN,
      usable,
      confidence: policy.confidence,
      official: policy.official,
      optIn: !!policy.optIn,
    };
  }

  /** Une source inconnue n'est jamais utilisable (§16). */
  function isUsableSourceType(sourceType, options) {
    return sourcePolicy(sourceType, options).usable;
  }

  /** Le type de source d'une observation temps réel (alias tolérés). */
  const OBSERVATION_SOURCE_ALIASES = Object.freeze({
    OFFICIAL: SOURCE_TYPES.OFFICIAL,
    OFFICIAL_REALTIME: SOURCE_TYPES.OFFICIAL,
    OPERATOR_REALTIME: SOURCE_TYPES.INSTITUTIONAL,
    INSTITUTIONAL: SOURCE_TYPES.INSTITUTIONAL,
    OPEN_DATA: SOURCE_TYPES.OPEN_DATA,
  });

  // ------------------------------------------------------------------
  // Référentiel de fréquences
  // ------------------------------------------------------------------

  function buildIndex(registry) {
    const sources = new Map();
    const frequenciesByLine = new Map();
    const all = [];
    const reg = registry || {};
    (reg.sources || []).forEach((s) => { if (s && s.id) sources.set(s.id, s); });
    (reg.frequencies || []).forEach((raw) => {
      if (!raw) return;
      // La fréquence hérite du type de source de la source liée : un chiffre
      // sans provenance reste inutilisable, il ne devient jamais crédible
      // parce qu'il est bien formé.
      const src = sources.get(raw.source_id || raw.sourceId) || null;
      const f = Object.assign({}, raw, {
        source_type: raw.source_type || (src && src.source_type) || null,
        source_label: raw.source_label || (src && (src.label || src.name)) || null,
        source_url: raw.source_url || (src && src.url) || null,
        retrieved_at: raw.retrieved_at || (src && src.retrieved_at) || null,
      });
      all.push(f);
      const key = f.line_id || f.lineId || '';
      if (!frequenciesByLine.has(key)) frequenciesByLine.set(key, []);
      frequenciesByLine.get(key).push(f);
    });
    return { sources, frequenciesByLine, frequencies: all, holidays: (reg.holidays && reg.holidays.dates) || [] };
  }

  function sourceRecordOf(index, sourceId) {
    return (index && index.sources && index.sources.get(sourceId)) || null;
  }

  /**
   * Une fréquence est-elle applicable à cette requête ? Vérifie ligne, arrêt,
   * sens, type de jour, validité temporelle ET statut du document.
   * Renvoie {applicable, reason, record, policy}.
   */
  function frequencyApplicability(frequency, query) {
    const q = query || {};
    if (!frequency) return { applicable: false, reason: REASONS.NO_FREQUENCY_FOR_LINE, record: null };

    const lineId = frequency.line_id || frequency.lineId || null;
    if (!lineId || !q.lineId || lineId !== q.lineId) {
      return { applicable: false, reason: REASONS.NO_FREQUENCY_FOR_LINE, record: frequency };
    }
    if (q.network && frequency.network && frequency.network !== q.network) {
      return { applicable: false, reason: REASONS.NO_FREQUENCY_FOR_LINE, record: frequency };
    }
    // Une fréquence portée par un arrêt précis ne vaut que pour cet arrêt.
    // Une fréquence de ligne (stop_id null) couvre tous les arrêts de la ligne.
    const fStop = frequency.stop_id == null ? null : frequency.stop_id;
    if (fStop && q.stopId && fStop !== q.stopId) {
      return { applicable: false, reason: REASONS.NO_FREQUENCY_FOR_LINE, record: frequency };
    }
    const fDir = frequency.direction == null ? null : frequency.direction;
    if (fDir && q.direction && fDir !== q.direction) {
      return { applicable: false, reason: REASONS.NO_FREQUENCY_FOR_LINE, record: frequency };
    }

    const dayTypes = frequency.day_types || frequency.dayTypes || [];
    if (q.dayType && Array.isArray(dayTypes) && dayTypes.length > 0 && !dayTypes.includes(q.dayType)) {
      return { applicable: false, reason: REASONS.NO_FREQUENCY_FOR_DAY, record: frequency };
    }

    const docStatus = String(frequency.status || FREQUENCY_STATUS.ACTIVE).toUpperCase();
    if (docStatus === FREQUENCY_STATUS.HISTORICAL || frequency.historical === true) {
      return { applicable: false, reason: REASONS.FREQUENCY_NOT_CURRENT, record: frequency };
    }
    if (frequency.valid_to && q.date && String(frequency.valid_to) < String(q.date)) {
      return { applicable: false, reason: REASONS.FREQUENCY_NOT_CURRENT, record: frequency };
    }
    if (frequency.valid_from && q.date && String(frequency.valid_from) > String(q.date)) {
      return { applicable: false, reason: REASONS.FREQUENCY_NOT_CURRENT, record: frequency };
    }
    return { applicable: true, reason: REASONS.FREQUENCY_ACTIVE, record: frequency };
  }

  /**
   * Sélectionne la fréquence applicable à l'instant demandé. Les enregistrements
   * dont la source n'est pas utilisable sont écartés (mais signalés).
   */
  function selectFrequency(frequencies, query) {
    const list = Array.isArray(frequencies) ? frequencies : [];
    const q = query || {};
    const rejected = [];
    let dayMismatch = null;
    const candidates = [];

    for (const f of list) {
      const verdict = frequencyApplicability(f, q);
      if (!verdict.applicable) {
        if (verdict.reason === REASONS.FREQUENCY_NOT_CURRENT) {
          rejected.push({ id: f.id || null, reason: REASONS.FREQUENCY_NOT_CURRENT, status: f.status || null });
        } else if (verdict.reason === REASONS.NO_FREQUENCY_FOR_DAY) {
          dayMismatch = f;
        }
        continue;
      }
      const linkedSource = (typeof q.resolveSource === 'function')
        ? q.resolveSource(f.source_id || f.sourceId)
        : null;
      const sourceType = f.source_type || (linkedSource && linkedSource.source_type) || SOURCE_TYPES.UNKNOWN;
      const policy = sourcePolicy(sourceType, { allowCommunity: !!q.allowCommunityFrequencies });
      if (!policy.usable) {
        rejected.push({
          id: f.id || null,
          reason: policy.optIn ? 'SOURCE_COMMUNITY_DISABLED' : REASONS.SOURCE_NOT_USABLE,
          sourceType: policy.sourceType,
        });
        continue;
      }
      candidates.push({ frequency: f, policy, ...frequencyRank(f, q.minutes) });
    }

    if (!candidates.length) return { frequency: null, policy: null, rejected, dayMismatch };

    // Plusieurs fréquences peuvent concerner la même ligne : celle qui couvre
    // l'instant présent prime, sinon la prochaine ouverture, sinon la période
    // terminée la plus tardive (pour pouvoir dire « service terminé »).
    candidates.sort((a, b) => (a.rank - b.rank) || (a.tieBreak - b.tieBreak));
    const best = candidates[0];
    return { frequency: best.frequency, policy: best.policy, rejected, dayMismatch: null };
  }

  /** Classement des périodes d'une même ligne au regard de l'instant courant. */
  function frequencyRank(frequency, nowMinutes) {
    const start = clockToMinutes(frequency.service_start || frequency.serviceStart);
    const end = clockToMinutes(frequency.service_end || frequency.serviceEnd);
    if (nowMinutes == null || start == null || end == null) return { rank: 2, tieBreak: 0 };
    if (nowMinutes >= start && nowMinutes < end) return { rank: 0, tieBreak: -end };
    if (nowMinutes < start) return { rank: 1, tieBreak: start };
    return { rank: 3, tieBreak: -end };
  }

  // ------------------------------------------------------------------
  // Modèle commun
  // ------------------------------------------------------------------

  /**
   * Toute valeur inconnue reste `null`. Aucun champ n'est complété pour
   * « faire joli » : un objet d'apparence complète est un objet faux.
   */
  function createEstimate(fields) {
    const f = fields || {};
    return {
      // — modèle demandé —
      network: f.network == null ? null : f.network,
      lineId: f.lineId == null ? null : f.lineId,
      stopId: f.stopId == null ? null : f.stopId,
      direction: f.direction == null ? null : f.direction,
      status: f.status == null ? STATUS.UNKNOWN : f.status,
      scheduledTime: f.scheduledTime == null ? null : f.scheduledTime,
      estimatedFrom: f.estimatedFrom == null ? null : f.estimatedFrom,
      estimatedTo: f.estimatedTo == null ? null : f.estimatedTo,
      frequencyMinutes: f.frequencyMinutes == null ? null : f.frequencyMinutes,
      source: f.source == null ? null : f.source,
      sourceType: f.sourceType == null ? null : f.sourceType,
      validFrom: f.validFrom == null ? null : f.validFrom,
      validTo: f.validTo == null ? null : f.validTo,
      observedAt: f.observedAt == null ? null : f.observedAt,
      confidence: f.confidence == null ? null : f.confidence,
      // — traçabilité additive (jamais présentée comme une donnée de service) —
      frequencyId: f.frequencyId == null ? null : f.frequencyId,
      retrievedAt: f.retrievedAt == null ? null : f.retrievedAt,
      evaluatedAt: f.evaluatedAt == null ? null : f.evaluatedAt,
      dayType: f.dayType == null ? null : f.dayType,
      serviceStart: f.serviceStart == null ? null : f.serviceStart,
      serviceEnd: f.serviceEnd == null ? null : f.serviceEnd,
      vehicleId: f.vehicleId == null ? null : f.vehicleId,
      eventId: f.eventId == null ? null : f.eventId,
      relative: f.relative == null ? null : f.relative,
      reason: f.reason == null ? null : f.reason,
      note: f.note == null ? null : f.note,
      usedSourceIsOfficial: f.usedSourceIsOfficial === true,
      simulated: false,
      warnings: Array.isArray(f.warnings) ? f.warnings.slice() : [],
      engineVersion: ENGINE_VERSION,
    };
  }

  /**
   * Contrôles internes. Toute violation est un bug du moteur, pas un cas à
   * afficher : les tests s'appuient sur cette fonction.
   */
  function validateEstimate(estimate) {
    const out = [];
    const e = estimate || {};
    const has = (v) => v != null;
    if (!STATUS_VALUES.includes(e.status)) out.push({ code: 'STATUS_INVALID', detail: String(e.status) });
    if (e.simulated === true) out.push({ code: 'SIMULATED_ESTIMATE', detail: 'une estimation ne peut pas être simulée' });
    if (e.status === STATUS.ESTIMATED) {
      if (has(e.scheduledTime)) out.push({ code: 'ESTIMATE_PRESENTED_AS_SCHEDULED', detail: String(e.scheduledTime) });
      if (e.frequencyMinutes == null) out.push({ code: 'ESTIMATE_WITHOUT_FREQUENCY', detail: 'aucune fréquence' });
      if (has(e.observedAt)) out.push({ code: 'ESTIMATE_PRESENTED_AS_REALTIME', detail: String(e.observedAt) });
      if (has(e.estimatedFrom) && has(e.estimatedTo)) {
        if (String(e.estimatedTo) <= String(e.estimatedFrom)) {
          out.push({ code: 'ESTIMATE_WINDOW_IS_NOT_A_WINDOW', detail: `${e.estimatedFrom} → ${e.estimatedTo}` });
        }
      } else {
        out.push({ code: 'ESTIMATE_WITHOUT_WINDOW', detail: 'fenêtre incomplète' });
      }
    }
    if (e.status === STATUS.SCHEDULED) {
      if (!has(e.scheduledTime)) out.push({ code: 'SCHEDULED_WITHOUT_TIME', detail: 'aucun horaire' });
      if (has(e.estimatedFrom) || has(e.estimatedTo)) {
        out.push({ code: 'SCHEDULED_DEGRADED_TO_ESTIMATE', detail: 'horaire précis converti en estimation' });
      }
      if (has(e.observedAt)) out.push({ code: 'SCHEDULED_PRESENTED_AS_REALTIME', detail: String(e.observedAt) });
    }
    if (e.status === STATUS.REAL_TIME) {
      if (!has(e.observedAt)) out.push({ code: 'REALTIME_WITHOUT_OBSERVATION', detail: 'aucun horodatage observé' });
      if (!has(e.vehicleId) && !has(e.eventId)) out.push({ code: 'REALTIME_WITHOUT_VEHICLE', detail: 'aucun véhicule/événement' });
      if (!has(e.source)) out.push({ code: 'REALTIME_WITHOUT_SOURCE', detail: 'aucune source' });
      if (has(e.scheduledTime)) out.push({ code: 'REALTIME_PRESENTED_AS_SCHEDULED', detail: String(e.scheduledTime) });
    }
    if (e.status === STATUS.UNKNOWN) {
      ['scheduledTime', 'estimatedFrom', 'estimatedTo', 'frequencyMinutes', 'observedAt'].forEach((k) => {
        if (has(e[k])) out.push({ code: 'UNKNOWN_WITH_TIME', detail: `${k}=${e[k]}` });
      });
    }
    if (e.frequencyMinutes != null && e.status !== STATUS.ESTIMATED) {
      out.push({ code: 'FREQUENCY_WITHOUT_ESTIMATE', detail: `${e.frequencyMinutes} min / ${e.status}` });
    }
    if (['HISTORICAL', 'UNKNOWN'].includes(String(e.sourceType)) && e.status !== STATUS.UNKNOWN) {
      out.push({ code: 'SERVICE_FROM_UNUSABLE_SOURCE', detail: `${e.sourceType} / ${e.status}` });
    }
    return out;
  }

  // ------------------------------------------------------------------
  // §11 — Fenêtre d'estimation (fonction commune)
  // ------------------------------------------------------------------

  /**
   * @param {Object} input
   *   currentTime  Date | ISO | {date, minutes}
   *   frequency    minutes (number) — fréquence de la période courante
   *   serviceStart "HH:MM"
   *   serviceEnd   "HH:MM" (dernier départ documenté)
   *   dayType      type de jour effectif (déjà résolu)
   * @returns {{status, estimatedFrom, estimatedTo, frequencyMinutes, relative, reason, note}}
   *   estimatedFrom/To sont des horodatages ISO locaux, null si UNKNOWN.
   */
  function estimateNextDepartureFromFrequency(input) {
    const o = input || {};
    const ref = normalizeNow(o.currentTime);
    const start = clockToMinutes(o.serviceStart);
    const end = clockToMinutes(o.serviceEnd);
    const freq = Number(o.frequency);

    const unknown = (reason, note) => ({
      status: STATUS.UNKNOWN,
      estimatedFrom: null,
      estimatedTo: null,
      frequencyMinutes: null,
      relative: null,
      reason,
      note: note == null ? null : note,
    });

    if (!ref) return unknown(REASONS.NO_DATA, 'Instant de référence invalide.');
    if (!Number.isFinite(freq) || freq <= 0) return unknown(REASONS.NO_DATA, 'Fréquence inconnue.');
    if (start == null || end == null) return unknown(REASONS.NO_DATA, 'Période de service inconnue.');
    if (end <= start) return unknown(REASONS.NO_DATA, 'Période de service incohérente.');

    const now = ref.minutes;
    if (now >= end) {
      return unknown(REASONS.SERVICE_ENDED, `Service terminé (dernier départ documenté ${o.serviceEnd}).`);
    }

    if (now < start) {
      // Avant le début de service : la fenêtre est ancrée sur l'ouverture
      // documentée, jamais sur une heure de départ inventée.
      const to = Math.min(start + freq, end);
      return {
        status: STATUS.ESTIMATED,
        estimatedFrom: isoLocalMinutes(ref.date, start),
        estimatedTo: isoLocalMinutes(ref.date, to),
        frequencyMinutes: freq,
        relative: 'BEFORE_SERVICE',
        reason: REASONS.FREQUENCY_BEFORE_SERVICE,
        note: `Service non commencé : premier passage estimé à partir de ${clockToDisplay(o.serviceStart)}.`,
      };
    }

    const to = Math.min(now + freq, end);
    const clamped = now + freq > end;
    return {
      status: STATUS.ESTIMATED,
      estimatedFrom: isoLocalMinutes(ref.date, now),
      estimatedTo: isoLocalMinutes(ref.date, to),
      frequencyMinutes: freq,
      relative: 'NOW',
      reason: REASONS.FREQUENCY_ACTIVE,
      note: clamped
        ? `Fin de période à ${o.serviceEnd} : la cadence suivante s’applique ensuite (aucune extrapolation).`
        : null,
    };
  }

  // ------------------------------------------------------------------
  // Observations réelles (REAL_TIME)
  // ------------------------------------------------------------------

  /**
   * Le GPS de l'utilisateur ne peut JAMAIS produire une position de véhicule.
   * Cette fonction est la seule porte d'entrée vers REAL_TIME et elle refuse
   * tout ce qui n'est pas une observation de véhicule réellement horodatée.
   */
  function classifyObservation(observation, options) {
    const o = observation || {};
    const opts = options || {};
    if (!o || typeof o !== 'object' || Object.keys(o).length === 0) {
      return { usable: false, reason: 'NOT_AN_OBSERVATION' };
    }
    if (o.simulated === true || o.mock === true || String(o.sourceType || '').toUpperCase() === 'SIMULATED') {
      return { usable: false, reason: 'SIMULATED_DATA_REFUSED' };
    }
    if (o.fromUserDevice === true || o.sourceKind === 'USER_DEVICE' || o.kind === 'USER_POSITION') {
      return { usable: false, reason: 'USER_POSITION_CANNOT_BE_VEHICLE' };
    }
    if (o.kind !== 'VEHICLE_OBSERVATION' && o.kind !== 'SERVICE_EVENT') {
      return { usable: false, reason: 'NOT_A_VEHICLE_OBSERVATION' };
    }
    if (!o.source) return { usable: false, reason: 'OBSERVATION_WITHOUT_SOURCE' };
    const mapped = OBSERVATION_SOURCE_ALIASES[String(o.sourceType || '').toUpperCase()];
    if (!mapped) return { usable: false, reason: 'OBSERVATION_SOURCE_NOT_REALTIME' };
    if (!o.observedAt) return { usable: false, reason: 'OBSERVATION_WITHOUT_TIMESTAMP' };
    if (!o.lineId && !o.routeId) return { usable: false, reason: 'OBSERVATION_WITHOUT_LINE' };
    if (!o.vehicleId && !o.eventId) return { usable: false, reason: 'OBSERVATION_WITHOUT_VEHICLE' };
    const hasEta = o.eta != null;
    const hasPosition = Number.isFinite(o.latitude) && Number.isFinite(o.longitude);
    if (!hasEta && !hasPosition) return { usable: false, reason: 'OBSERVATION_WITHOUT_POSITION_OR_ETA' };

    const ref = normalizeNow(opts.now == null ? Date.now() : opts.now);
    const observedRef = normalizeNow(o.observedAt);
    if (ref && observedRef) {
      const ageMinutes = Math.abs(ref.minutes - observedRef.minutes) +
        (ref.date === observedRef.date ? 0 : 1440);
      if (ageMinutes > (opts.maxAgeMinutes || OBSERVATION_MAX_AGE_MINUTES)) {
        return { usable: false, reason: 'OBSERVATION_STALE' };
      }
    }
    return {
      usable: true,
      reason: REASONS.OBSERVED_VEHICLE,
      sourceType: mapped,
      observedAt: typeof o.observedAt === 'string' ? o.observedAt : isoLocalMinutes(observedRef.date, observedRef.minutes),
      eta: hasEta ? String(o.eta) : null,
      vehicleId: o.vehicleId == null ? null : o.vehicleId,
      eventId: o.eventId == null ? null : o.eventId,
      source: o.source,
    };
  }

  function pickObservation(observations, query, options) {
    const list = Array.isArray(observations) ? observations : [];
    const rejected = [];
    for (const o of list) {
      const verdict = classifyObservation(o, options);
      if (!verdict.usable) { rejected.push({ reason: verdict.reason, vehicleId: o && o.vehicleId ? o.vehicleId : null }); continue; }
      if (query && query.lineId && verdict.lineId && verdict.lineId !== query.lineId) continue;
      const lineId = (o && (o.lineId || o.routeId)) || null;
      if (query && query.lineId && lineId && lineId !== query.lineId) continue;
      return { observation: verdict, raw: o, rejected };
    }
    return { observation: null, raw: null, rejected };
  }

  // ------------------------------------------------------------------
  // Cœur : estimateNextDeparture
  // ------------------------------------------------------------------

  /**
   * @param {Object} input  (tous les champs sont optionnels sauf `now`)
   *   now, network, lineId, stopId, direction
   *   registry        référentiel departure-frequencies.json
   *   frequencies     liste brute (alternative à registry)
   *   sources         liste des sources (alternative à registry)
   *   holidays        dates "YYYY-MM-DD" explicitement déclarées
   *   scheduledDepartures  [{time:"11:40"|iso, source, sourceType, validFrom, validTo, lineId, stopId, direction}]
   *   observations    [{kind:'VEHICLE_OBSERVATION', source, sourceType, observedAt, lineId, vehicleId, eta, latitude, longitude}]
   *   preferObservedRealtime  false (défaut) = ordre strict de la spécification
   *                           true = une observation réelle passe devant la fréquence
   *   allowCommunityFrequencies false (défaut)
   * @returns {DepartureEstimate}
   */
  function estimateNextDeparture(input) {
    const o = input || {};
    const now = normalizeNow(o.now == null ? Date.now() : o.now);
    const registryIndex = buildIndex(o.registry);
    const frequencies = Array.isArray(o.frequencies) && o.frequencies.length
      ? o.frequencies
      : registryIndex.frequencies;
    const holidays = Array.isArray(o.holidays) ? o.holidays : registryIndex.holidays;
    const sourcesList = Array.isArray(o.sources) ? o.sources : Array.from(registryIndex.sources.values());

    const base = {
      network: o.network == null ? null : o.network,
      lineId: o.lineId == null ? null : o.lineId,
      stopId: o.stopId == null ? null : o.stopId,
      direction: o.direction == null ? null : o.direction,
      evaluatedAt: now ? now.iso : null,
    };

    if (!now) {
      return createEstimate({ ...base, status: STATUS.UNKNOWN, reason: REASONS.NO_DATA, note: 'Instant de référence invalide.' });
    }

    const dayType = o.dayType || dayTypeOf(now, holidays);
    const warnings = [];

    const findSource = (id) => sourcesList.find((s) => s && s.id === id) || sourceRecordOf(registryIndex, id) || null;
    const withSource = (record) => {
      const src = record ? findSource(record.source_id || record.sourceId) : null;
      return {
        source: src ? (src.label || src.name || src.id) : null,
        sourceType: (src && src.source_type) || (record && record.source_type) || null,
        retrievedAt: src && src.retrieved_at ? src.retrieved_at : null,
      };
    };

    // ---- 1/2. Horaire précis fiable → SCHEDULED -------------------------
    const scheduled = pickScheduledDeparture(o.scheduledDepartures, { ...o, date: now.date, minutes: now.minutes });
    const observation = pickObservation(o.observations, o, { now: o.now == null ? Date.now() : o.now, maxAgeMinutes: o.observationMaxAgeMinutes });

    const buildScheduled = (record, policy) => {
      const entry = withSource(record);
      const time = record.time && String(record.time).includes('T')
        ? String(record.time)
        : isoLocalMinutes(now.date, clockToMinutes(record.time));
      return createEstimate({
        ...base,
        status: STATUS.SCHEDULED,
        scheduledTime: time,
        source: record.source || entry.source,
        sourceType: record.sourceType || entry.sourceType,
        validFrom: record.validFrom || record.valid_from || null,
        validTo: record.validTo || record.valid_to || null,
        confidence: policy.confidence,
        dayType,
        sourceRecordId: null,
        usedSourceIsOfficial: policy.official,
        reason: REASONS.SCHEDULED_TIMETABLE,
        relative: 'SCHEDULED',
      });
    };

    const buildRealtime = (obs, raw) => createEstimate({
      ...base,
      status: STATUS.REAL_TIME,
      estimatedFrom: obs.eta,
      estimatedTo: obs.eta,
      observedAt: obs.observedAt,
      vehicleId: obs.vehicleId,
      eventId: obs.eventId,
      source: obs.source,
      sourceType: obs.sourceType,
      direction: raw && raw.direction != null ? raw.direction : base.direction,
      confidence: 'high',
      dayType,
      reason: REASONS.OBSERVED_VEHICLE,
      relative: 'REALTIME',
      note: 'Observation réelle horodatée : ce n’est pas une estimation de fréquence.',
    });

    const buildFrequencyEstimate = (frequency, policy) => {
      const src = withSource(frequency);
      const window = estimateNextDepartureFromFrequency({
        currentTime: now,
        frequency: frequency.frequency_minutes != null ? frequency.frequency_minutes : frequency.frequencyMinutes,
        serviceStart: frequency.service_start || frequency.serviceStart,
        serviceEnd: frequency.service_end || frequency.serviceEnd,
        dayType,
      });
      if (window.status !== STATUS.ESTIMATED) {
        return createEstimate({
          ...base,
          status: STATUS.UNKNOWN,
          frequencyMinutes: null,
          source: src.source,
          sourceType: src.sourceType,
          reason: window.reason,
          note: window.note,
          dayType,
          warnings: [...warnings, ...(observation.rejected || []).map((r) => ({ code: r.reason }))],
        });
      }
      return createEstimate({
        ...base,
        status: STATUS.ESTIMATED,
        estimatedFrom: window.estimatedFrom,
        estimatedTo: window.estimatedTo,
        frequencyMinutes: window.frequencyMinutes,
        source: src.source,
        sourceType: src.sourceType,
        validFrom: frequency.valid_from || frequency.validFrom || null,
        validTo: frequency.valid_to || frequency.validTo || null,
        confidence: frequency.confidence || policy.confidence,
        frequencyId: frequency.id || null,
        retrievedAt: src.retrievedAt,
        dayType,
        serviceStart: frequency.service_start || frequency.serviceStart || null,
        serviceEnd: frequency.service_end || frequency.serviceEnd || null,
        relative: window.relative,
        reason: window.reason,
        note: window.note,
        usedSourceIsOfficial: policy.official,
      });
    };

    const finish = (estimate) => {
      const nextWarnings = (estimate.warnings || []).concat(warnings);
      const merged = { ...estimate, warnings: nextWarnings };
      return merged;
    };

    // Ordre strict de la spécification : SCHEDULED → ESTIMATED → REAL_TIME.
    if (scheduled && !o.preferObservedRealtime) return finish(buildScheduled(scheduled.record, scheduled.policy));

    const selection = selectFrequency(frequencies, {
      network: o.network,
      lineId: o.lineId,
      stopId: o.stopId,
      direction: o.direction,
      dayType,
      date: now.date,
      minutes: now.minutes,
      allowCommunityFrequencies: !!o.allowCommunityFrequencies,
      resolveSource: (id) => findSource(id),
    });
    (selection.rejected || []).forEach((r) => warnings.push({ code: r.reason, frequencyId: r.id, sourceType: r.sourceType }));

    if (o.preferObservedRealtime) {
      if (observation.observation) return finish(buildRealtime(observation.observation, observation.raw));
      if (scheduled) return finish(buildScheduled(scheduled.record, scheduled.policy));
      if (selection.frequency) return finish(buildFrequencyEstimate(selection.frequency, selection.policy));
    } else {
      if (selection.frequency) return finish(buildFrequencyEstimate(selection.frequency, selection.policy));
      if (observation.observation) return finish(buildRealtime(observation.observation, observation.raw));
    }

    // ---- 4. Rien de fiable → UNKNOWN ------------------------------------
    (observation.rejected || []).forEach((r) => warnings.push({ code: r.reason }));
    let reason = REASONS.NO_FREQUENCY_FOR_LINE;
    let note = 'Aucune fréquence documentée pour cette ligne.';
    if (selection.dayMismatch) {
      reason = REASONS.NO_FREQUENCY_FOR_DAY;
      note = 'Fréquence documentée pour d’autres jours seulement : aucune estimation pour ce jour.';
    } else if (warnings.some((w) => w.code === REASONS.FREQUENCY_NOT_CURRENT)) {
      reason = REASONS.FREQUENCY_NOT_CURRENT;
      note = 'Seule une donnée historique existe : elle ne décrit pas le service actuel.';
    } else if (warnings.some((w) => w.code === REASONS.SOURCE_NOT_USABLE || w.code === 'SOURCE_COMMUNITY_DISABLED')) {
      reason = REASONS.SOURCE_NOT_USABLE;
      note = 'Source pas assez fiable pour produire une estimation.';
    } else if (!o.lineId) {
      reason = REASONS.NO_FREQUENCY_FOR_LINE;
      note = 'Ligne inconnue : aucune estimation possible.';
    }

    return finish(createEstimate({
      ...base,
      status: STATUS.UNKNOWN,
      dayType,
      reason,
      note,
      confidence: 'none',
    }));
  }

  /** Premier horaire programmé strictement postérieur à l'instant courant. */
  function pickScheduledDeparture(list, query) {
    const opts = query || {};
    const entries = Array.isArray(list) ? list : [];
    const candidates = [];
    for (const raw of entries) {
      if (!raw || raw.time == null) continue;
      const policy = sourcePolicy(raw.sourceType || raw.source_type);
      if (!policy.usable) continue;
      if (opts.lineId && raw.lineId && raw.lineId !== opts.lineId) continue;
      if (opts.stopId && raw.stopId && raw.stopId !== opts.stopId) continue;
      if (opts.direction && raw.direction && raw.direction !== opts.direction) continue;
      if (opts.date) {
        if (raw.validFrom && String(raw.validFrom) > opts.date) continue;
        if (raw.validTo && String(raw.validTo) < opts.date) continue;
      }
      const minutes = String(raw.time).includes('T')
        ? clockToMinutes(String(raw.time).slice(11, 16))
        : clockToMinutes(raw.time);
      if (minutes == null) continue;
      if (opts.minutes != null && minutes <= opts.minutes) continue;
      candidates.push({ record: { ...raw, time: raw.time }, policy, minutes });
    }
    if (!candidates.length) return null;
    candidates.sort((a, b) => a.minutes - b.minutes);
    return candidates[0];
  }

  // ------------------------------------------------------------------
  // GPS — usages autorisés de la position utilisateur
  // ------------------------------------------------------------------

  const USER_POSITION_USES = Object.freeze(['LOCALISATION', 'STOP_PROXIMITY', 'DISTANCE', 'ROUTING']);

  /**
   * La position de l'utilisateur sert à se localiser, chercher les arrêts
   * proches, calculer une proximité et aider au routage. Elle ne produit
   * jamais de position de véhicule : cette fonction renvoie `null`.
   */
  function vehicleFromUserPosition() { return null; }

  // ------------------------------------------------------------------
  // §17 — Affichage (le composant existant choisit, il ne recalcule rien)
  // ------------------------------------------------------------------

  function formatClock(iso) {
    if (typeof iso !== 'string' || iso.length < 16) return null;
    return clockToDisplay(iso.slice(11, 16));
  }

  // Accord du mot « minute » : « 0 à 1 minute », « 0 à 10 minutes ». Le
  // singulier apparaît en fin de service (dernier départ documenté).
  function minuteWord(n) {
    return Number(n) === 1 ? 'minute' : 'minutes';
  }

  function minutesBetween(fromIso, toIso) {
    if (typeof fromIso !== 'string' || typeof toIso !== 'string') return null;
    const a = clockToMinutes(fromIso.slice(11, 16));
    const b = clockToMinutes(toIso.slice(11, 16));
    if (a == null || b == null) return null;
    return b - a;
  }

  /**
   * Libellés d'interface. Aucune heure précise n'est produite pour une
   * estimation : uniquement une fenêtre ou un intervalle en minutes.
   */
  function displayFor(estimate, options) {
    const e = estimate || createEstimate({ status: STATUS.UNKNOWN });
    const opts = options || {};
    const ref = normalizeNow(opts.now == null ? Date.now() : opts.now);
    const official = e.usedSourceIsOfficial === true &&
      [SOURCE_TYPES.OFFICIAL, SOURCE_TYPES.INSTITUTIONAL].includes(String(e.sourceType));

    switch (e.status) {
      case STATUS.SCHEDULED: {
        const clock = formatClock(e.scheduledTime);
        return {
          status: STATUS.SCHEDULED,
          badge: LABELS.SCHEDULED,
          title: `Départ ${clock}`,
          headline: `Départ ${clock}`,
          body: 'Horaire programmé',
          detail: e.source ? `Source : ${e.source}` : null,
          isOfficial: official,
          isEstimate: false,
          isRealTime: false,
          available: true,
        };
      }
      case STATUS.ESTIMATED: {
        const fromMin = e.estimatedFrom && ref ? e.estimatedFrom.slice(11, 16) : null;
        const toMin = e.estimatedTo && ref ? e.estimatedTo.slice(11, 16) : null;
        const w1 = fromMin && ref ? Math.max(0, clockToMinutes(fromMin) - ref.minutes) : 0;
        const w2 = toMin && ref ? Math.max(w1, clockToMinutes(toMin) - ref.minutes) : (e.frequencyMinutes || 0);
        const windowLabel = `${w1}–${w2} min`;
        const clockWindow = `Passage estimé ${clockToDisplay(fromMin)} – ${clockToDisplay(toMin)}`;
        if (e.relative === 'BEFORE_SERVICE') {
          return {
            status: STATUS.ESTIMATED,
            badge: LABELS.ESTIMATED,
            title: 'Premier passage estimé',
            headline: `Premier passage estimé entre ${clockToDisplay(fromMin)} et ${clockToDisplay(toMin)}`,
            windowLabel,
            clockWindowLabel: clockWindow,
            body: `Service non commencé (ouverture documentée à ${e.serviceStart})`,
            detail: e.source
              ? `Estimation à partir d’une fréquence documentée (${e.frequencyMinutes} min) — source : ${e.source}`
              : `Estimation à partir d’une fréquence documentée (${e.frequencyMinutes} min)`,
            trafficNote: 'Le passage réel peut varier selon l’exploitation et la circulation.',
            isOfficial: false,
            isEstimate: true,
            isRealTime: false,
            available: true,
          };
        }
        return {
          status: STATUS.ESTIMATED,
          badge: LABELS.ESTIMATED,
          title: 'Prochain passage estimé',
          headline: `Prochain passage estimé dans ${windowLabel}`,
          windowLabel,
          clockWindowLabel: clockWindow,
          body: clockWindow,
          detail: e.source
            ? `Estimation à partir d’une fréquence documentée (${e.frequencyMinutes} min) — source : ${e.source}`
            : `Estimation à partir d’une fréquence documentée (${e.frequencyMinutes} min)`,
          trafficNote: 'Le passage réel peut varier selon l’exploitation et la circulation.',
          isOfficial: false,
          isEstimate: true,
          isRealTime: false,
          available: true,
        };
      }
      case STATUS.REAL_TIME: {
        const etaMin = e.estimatedFrom && ref ? Math.max(0, clockToMinutes(e.estimatedFrom.slice(11, 16)) - ref.minutes) : null;
        const title = etaMin == null ? 'Passage observé' : `Arrivée dans ${etaMin} min`;
        return {
          status: STATUS.REAL_TIME,
          badge: LABELS.REAL_TIME,
          title,
          headline: title,
          body: `Véhicule ${e.vehicleId || e.eventId || 'observé'} — observé à ${formatClock(e.observedAt) || '—'}`,
          detail: e.source ? `Source : ${e.source}` : null,
          isOfficial: official,
          isEstimate: false,
          isRealTime: true,
          available: true,
        };
      }
      default:
        return {
          status: STATUS.UNKNOWN,
          badge: LABELS.UNKNOWN,
          title: 'Prochain passage',
          headline: 'Prochain passage',
          body: LABELS.UNKNOWN,
          detail: null,
          isOfficial: false,
          isEstimate: false,
          isRealTime: false,
          available: false,
        };
    }
  }

  // ------------------------------------------------------------------
  // §18 — Assistant IA (mêmes statuts, même moteur)
  // ------------------------------------------------------------------

  function assistantReply(estimate, options) {
    const e = estimate || createEstimate({ status: STATUS.UNKNOWN });
    const opts = options || {};
    const mode = opts.mode || e.network || 'réseau';
    const vehicleWord = String(mode).toUpperCase() === 'TER' ? 'du train' : 'du bus';
    const ref = normalizeNow(opts.now == null ? Date.now() : opts.now);

    switch (e.status) {
      case STATUS.SCHEDULED: {
        const clock = formatClock(e.scheduledTime);
        const source = e.source ? ` (source : ${e.source})` : '';
        return `Le ${mode} est disponible dans cette direction. Départ programmé à ${clock}${source}.`;
      }
      case STATUS.ESTIMATED: {
        const from = e.estimatedFrom ? clockToMinutes(e.estimatedFrom.slice(11, 16)) : null;
        const to = e.estimatedTo ? clockToMinutes(e.estimatedTo.slice(11, 16)) : null;
        const w1 = from != null && ref ? Math.max(0, from - ref.minutes) : 0;
        const w2 = to != null && ref ? Math.max(w1, to - ref.minutes) : (e.frequencyMinutes || 0);
        if (e.relative === 'BEFORE_SERVICE') {
          return `Le ${mode} est disponible dans cette direction. Le service commence à ${e.serviceStart} : ` +
            `le premier passage est estimé entre ${clockToDisplay(minutesToClock(from))} et ` +
            `${clockToDisplay(minutesToClock(to))}. L'heure exacte ${vehicleWord} n'est pas disponible.`;
        }
        return `Le ${mode} est disponible dans cette direction. Le prochain passage est estimé dans une ` +
          `fenêtre de ${w1} à ${w2} ${minuteWord(w2)}. L'heure exacte ${vehicleWord} n'est pas disponible.`;
      }
      case STATUS.REAL_TIME: {
        const etaMin = e.estimatedFrom && ref ? Math.max(0, clockToMinutes(e.estimatedFrom.slice(11, 16)) - ref.minutes) : null;
        return `Véhicule ${e.vehicleId || e.eventId || 'observé'} observé à ${formatClock(e.observedAt) || '—'}` +
          `${etaMin == null ? '' : ` ; arrivée estimée dans ${etaMin} ${minuteWord(etaMin)}`} (temps réel, source : ${e.source || 'opérateur'}).`;
      }
      default:
        return 'Je connais cette ligne, mais je n’ai pas actuellement de donnée suffisamment fiable ' +
          'pour estimer le prochain passage.';
    }
  }

  // ------------------------------------------------------------------
  // §19 — Itinéraires : ne jamais dépasser la précision de la source
  // ------------------------------------------------------------------

  /**
   * Une jambe d'itinéraire hérite EXACTEMENT du statut du départ. Une fenêtre
   * de départ produit une fenêtre d'arrivée — jamais « vous arriverez
   * exactement à 12h17 ».
   */
  function planItineraryLeg(estimate, options) {
    const e = estimate || createEstimate({ status: STATUS.UNKNOWN });
    const opts = options || {};
    const duration = Number.isFinite(opts.durationMinutes) ? Math.max(0, Math.round(opts.durationMinutes)) : null;
    const add = (iso) => {
      if (iso == null || duration == null) return null;
      const clock = clockToMinutes(iso.slice(11, 16));
      if (clock == null) return null;
      return isoLocalMinutes(iso.slice(0, 10), clock + duration);
    };

    if (e.status === STATUS.SCHEDULED) {
      return {
        status: e.status,
        precision: 'EXACT',
        departureTime: e.scheduledTime,
        arrivalTime: add(e.scheduledTime),
        departureWindow: null,
        arrivalWindow: null,
        durationIsEstimate: duration != null,
        note: 'Horaire programmé — durée de parcours estimée.',
      };
    }
    if (e.status === STATUS.ESTIMATED) {
      return {
        status: e.status,
        precision: 'WINDOW',
        departureTime: null,
        arrivalTime: null,
        departureWindow: [e.estimatedFrom, e.estimatedTo],
        arrivalWindow: [add(e.estimatedFrom), add(e.estimatedTo)],
        durationIsEstimate: duration != null,
        note: 'Départ estimé : l’arrivée reste une fenêtre, l’incertitude est conservée.',
      };
    }
    if (e.status === STATUS.REAL_TIME) {
      return {
        status: e.status,
        precision: 'REALTIME_DEPARTURE_PLUS_ESTIMATED_TRAVEL',
        departureTime: e.estimatedFrom,
        arrivalTime: add(e.estimatedFrom),
        departureWindow: null,
        arrivalWindow: null,
        durationIsEstimate: duration != null,
        note: 'Départ observé ; durée de parcours estimée.',
      };
    }
    return {
      status: STATUS.UNKNOWN,
      precision: 'NONE',
      departureTime: null,
      arrivalTime: null,
      departureWindow: null,
      arrivalWindow: null,
      durationIsEstimate: duration != null,
      note: 'Horaire indisponible : aucune heure de départ ou d’arrivée n’est annoncée.',
    };
  }

  // ------------------------------------------------------------------
  // Contrôles du référentiel
  // ------------------------------------------------------------------

  /** Erreurs bloquantes dans un référentiel de fréquences. */
  function validateFrequencyRegistry(registry) {
    const out = [];
    const reg = registry || {};
    const sources = new Map();
    (reg.sources || []).forEach((s) => {
      if (!s || !s.id) { out.push({ code: 'SOURCE_WITHOUT_ID' }); return; }
      sources.set(s.id, s);
      if (!s.source_type || !SOURCE_POLICY[String(s.source_type).toUpperCase()]) {
        out.push({ code: 'SOURCE_TYPE_INVALID', id: s.id, detail: String(s.source_type) });
      }
      if (String(s.source_type).toUpperCase() === SOURCE_TYPES.OFFICIAL && !s.url) {
        out.push({ code: 'OFFICIAL_SOURCE_WITHOUT_URL', id: s.id });
      }
    });
    (reg.frequencies || []).forEach((f) => {
      const id = f && f.id;
      if (!id) { out.push({ code: 'FREQUENCY_WITHOUT_ID' }); return; }
      if (!f.line_id) out.push({ code: 'FREQUENCY_WITHOUT_LINE', id });
      if (!Number.isFinite(f.frequency_minutes) || f.frequency_minutes <= 0) {
        out.push({ code: 'FREQUENCY_INVALID_MINUTES', id, detail: String(f.frequency_minutes) });
      }
      if (clockToMinutes(f.service_start) == null || clockToMinutes(f.service_end) == null) {
        out.push({ code: 'FREQUENCY_INVALID_SERVICE_WINDOW', id });
      } else if (clockToMinutes(f.service_end) <= clockToMinutes(f.service_start)) {
        out.push({ code: 'FREQUENCY_SERVICE_WINDOW_INVERTED', id });
      }
      if (!Array.isArray(f.day_types) || f.day_types.length === 0) {
        out.push({ code: 'FREQUENCY_WITHOUT_DAY_TYPE', id });
      } else {
        f.day_types.forEach((d) => {
          if (!Object.values(DAY_TYPES).includes(d)) out.push({ code: 'FREQUENCY_DAY_TYPE_INVALID', id, detail: String(d) });
        });
      }
      if (!f.source_id || !sources.has(f.source_id)) out.push({ code: 'FREQUENCY_WITHOUT_VALID_SOURCE', id, detail: String(f.source_id) });
      const status = String(f.status || 'ACTIVE').toUpperCase();
      if (!Object.values(FREQUENCY_STATUS).includes(status)) out.push({ code: 'FREQUENCY_STATUS_INVALID', id, detail: status });
    });
    return out;
  }

  /** Observations non bloquantes (une fréquence de ligne n'est pas une donnée d'arrêt). */
  function frequencyWarnings(registry) {
    const out = [];
    ((registry || {}).frequencies || []).forEach((f) => {
      if (!f) return;
      if (f.direction == null) out.push({ code: 'FREQUENCY_WITHOUT_DIRECTION', id: f.id, detail: 'fréquence documentée au niveau de la ligne' });
      if (f.valid_to == null) out.push({ code: 'FREQUENCY_WITHOUT_END_OF_VALIDITY', id: f.id });
      if (!(f.stop_id || f.stopId)) out.push({ code: 'FREQUENCY_IS_LINE_LEVEL_NOT_STOP_LEVEL', id: f.id });
    });
    return out;
  }

  return {
    ENGINE_VERSION,
    STATUS,
    STATUS_VALUES,
    LABELS,
    SOURCE_TYPES,
    SOURCE_POLICY,
    FREQUENCY_STATUS,
    DAY_TYPES,
    REASONS,
    USER_POSITION_USES,
    OBSERVATION_MAX_AGE_MINUTES,

    // temps
    isValidClock,
    clockToMinutes,
    minutesToClock,
    clockToDisplay,
    dateStringOf,
    dayNameOf,
    dayTypeOf,
    isoLocalMinutes,
    normalizeNow,
    formatClock,
    minutesBetween,

    // politique de source
    sourcePolicy,
    isUsableSourceType,

    // référentiel
    buildIndex,
    frequencyApplicability,
    selectFrequency,
    validateFrequencyRegistry,
    frequencyWarnings,

    // moteur
    createEstimate,
    validateEstimate,
    estimateNextDepartureFromFrequency,
    estimateNextDeparture,
    pickScheduledDeparture,

    // observations / GPS
    classifyObservation,
    vehicleFromUserPosition,

    // présentation
    displayFor,
    assistantReply,
    planItineraryLeg,
    legacyStatusToStatus,
  };
});
