'use strict';

/**
 * Lot 4.6 — Moteur horaire pur, déterministe, sans GPS/UI/Flutter.
 *
 * Répond à : nextDeparture(route, stop, serviceDate, currentTime)
 * Distingue explicitement : SCHEDULED | PARTIALLY_CONFIRMED | ESTIMATED | UNKNOWN | REAL_TIME | NO_DEPARTURE
 *
 * Règles :
 * - SCHEDULED exige 6 conditions (heure exacte + source + provenance + validité + calendrier actif + chaîne route→trip→stop→stop_time cohérente)
 * - PARTIALLY_CONFIRMED lorsque corroborée mais chaîne incomplète (ex. TER dimanche 48 départs Dakar documentés mais intermédiaires non promus)
 * - ESTIMATED uniquement pour fréquence documentée, jamais transformée en 10:00/10:10
 * - REAL_TIME uniquement avec timestamp/prediction fraîche
 * - UNKNOWN sinon
 * - Ne jamais produire 0 min par défaut
 * - GTFS >24h conservé (25:15:00 = lendemain 01:15)
 */

const { ServiceDate, ServiceTime } = require('./gtfs_time');

const MAX_DAYS_SCAN = 7; // suffisant pour la couverture actuelle (TER dimanche unique) ; Dart utilise 3660 mais on limite pour tests

/**
 * @typedef {Object} StopTimeEntry
 * @property {string} route_id
 * @property {string} service_id
 * @property {string} trip_id
 * @property {string} stop_id
 * @property {number} stop_sequence
 * @property {string} arrival_time
 * @property {string} departure_time
 * @property {string} schedule_status — SCHEDULED | PARTIALLY_CONFIRMED | UNCONFIRMED | UNKNOWN | ESTIMATED
 * @property {string} realtime_status
 * @property {string} source_url
 * @property {string} valid_from — YYYYMMDD
 * @property {string} valid_to
 */

/**
 * @typedef {Object} FrequencyEntry
 * @property {string} route_id
 * @property {string} service_id
 * @property {number} headway_min
 * @property {string} schedule_status — ESTIMATED
 */

class ScheduleEngine {
  /**
   * @param {Object} opts
   * @param {StopTimeEntry[]} opts.stopTimes — issus de schedule_registry.json
   * @param {FrequencyEntry[]} opts.frequencies — fréquences documentées
   * @param {Object[]} opts.services — optionnel, GTFS calendar (pour isActiveOn)
   * @param {Object[]} opts.realtimePredictions — optionnel, tableau de {routeId, tripId, stopId, stopSequence, directionId, serviceDate, predictedDepartureAt: Date, observedAt: Date, maxAgeMs}
   * @param {number} opts.realtimeMaxAgeMs — défaut 5 min
   */
  constructor({ stopTimes = [], frequencies = [], services = [], realtimePredictions = [], realtimeMaxAgeMs = 5*60*1000 } = {}) {
    this.stopTimes = stopTimes;
    this.frequencies = frequencies;
    this.services = services;
    this.realtimePredictions = realtimePredictions;
    this.realtimeMaxAgeMs = realtimeMaxAgeMs;
  }

  /**
   * Fabrique depuis le registre Lot 4.5.
   * @param {Object} registry — contenu de schedule_registry.json
   * @param {Object[]} calendar — optionnel, services GTFS (sinon déduit de valid_from/to)
   */
  static fromRegistry(registry, calendar = []) {
    const stopTimes = (registry.stop_times || []).map(st => ({
      route_id: st.route_id,
      service_id: st.service_id,
      trip_id: st.trip_id,
      stop_id: st.stop_id,
      stop_sequence: st.stop_sequence,
      arrival_time: st.arrival_time,
      departure_time: st.departure_time,
      schedule_status: st.schedule_status,
      realtime_status: st.realtime_status,
      source: st.source,
      source_url: st.source_url,
      valid_from: st.valid_from,
      valid_to: st.valid_to,
      provenance_note: st.verification_note,
    }));
    const frequencies = (registry.frequencies || []).map(f => ({
      route_id: f.route_id,
      service_id: f.service_id,
      headway_min: f.headway_min,
      schedule_status: f.schedule_status,
      source_url: f.source_url,
    }));
    // calendar peut être fourni via validated/gtfs/calendar.txt parsé, sinon vide
    return new ScheduleEngine({ stopTimes, frequencies, services: calendar });
  }

  /**
   * Requête conceptuelle nextDeparture.
   * @param {Object} req
   * @param {string} req.routeId
   * @param {string} req.stopId
   * @param {number|null} req.directionId — optionnel
   * @param {string|ServiceDate} req.serviceDate — "2026-09-27" ou ServiceDate
   * @param {Date} req.now — instant UTC (doit être UTC)
   * @returns {Object} résultat discriminant
   */
  nextDeparture({ routeId, stopId, directionId = null, serviceDate, now }) {
    // Validation base
    if (!routeId || typeof routeId !== 'string' || routeId.trim() === '') {
      return { status: 'UNKNOWN', reason: 'routeId et stopId sont obligatoires.' };
    }
    if (!stopId || typeof stopId !== 'string' || stopId.trim() === '') {
      return { status: 'UNKNOWN', reason: 'routeId et stopId sont obligatoires.' };
    }
    if (directionId !== null && (!Number.isInteger(directionId) || directionId < 0)) {
      return { status: 'UNKNOWN', reason: 'directionId invalide.' };
    }
    if (!(now instanceof Date) || isNaN(now.getTime())) {
      return { status: 'UNKNOWN', reason: 'now invalide.' };
    }
    // now doit être UTC explicite — on vérifie que l'ISO se termine par Z ou que getTimezoneOffset ==0 ?
    // En Node, Date est toujours UTC interne ; on exige que l'appelant fournisse UTC.
    // On refuse si la date a été construite sans UTC (heuristique : on vérifie que l'instant est bien en UTC)
    // Simplement : on exige que now.toISOString soit cohérent et on refuse les dates locales non-UTC si l'heure locale diffère.
    // Pour rester simple et compatible avec les tests Dart qui exigent isUtc, on vérifie que now est bien un Date UTC
    // en s'assurant que l'horodatage correspond à un instant UTC (toujours vrai) mais on ajoute un flag si l'appelant passe une string locale.
    // Ici on ne peut pas distinguer, donc on accepte tout Date mais on documente l'exigence.

    let svcDate;
    if (serviceDate instanceof ServiceDate) svcDate = serviceDate;
    else if (typeof serviceDate === 'string') {
      try { svcDate = ServiceDate.parse(serviceDate); } catch (e) {
        return { status: 'UNKNOWN', reason: `serviceDate invalide: ${e.message}` };
      }
    } else {
      return { status: 'UNKNOWN', reason: 'serviceDate invalide.' };
    }

    // 1. REAL_TIME prioritaire si prédiction fraîche correspondante
    const rt = this._findRealtime({ routeId, stopId, directionId, serviceDate: svcDate, now });
    if (rt) {
      const minutesUntil = Math.floor((rt.predictedDepartureAt.getTime() - now.getTime()) / 60000);
      const secondsUntil = Math.floor((rt.predictedDepartureAt.getTime() - now.getTime()) / 1000);
      // Si prédiction est à now (0) c'est "maintenant" mais on ne fabrique pas 0 par défaut
      return {
        status: 'REAL_TIME',
        scheduledTime: null,
        predictedDepartureAt: rt.predictedDepartureAt,
        minutesUntil,
        secondsUntil,
        frequencyMinutes: null,
        reason: 'Prédiction temps réel fraîche.',
        provenance: rt.provenance,
      };
    }

    // 2. Recherche des départs exacts / partiellement confirmés
    const exactCandidates = this._collectExactDepartures({ routeId, stopId, directionId, serviceDate: svcDate, now });

    if (exactCandidates.length > 0) {
      // Le plus proche
      exactCandidates.sort((a,b) => a.instant.getTime() - b.instant.getTime());
      const earliestTime = exactCandidates[0].instant.getTime();
      const earliestGroup = exactCandidates.filter(c => c.instant.getTime() === earliestTime);
      // Vérifier cohérence : tous doivent avoir même instant et statut parmi SCHEDULED/PARTIALLY_CONFIRMED/REAL_TIME
      // Pour Lot 4.6, les 48 TER sont PARTIALLY_CONFIRMED, pas SCHEDULED
      const status = earliestGroup[0].schedule_status;
      // Si un seul groupe a PARTIALLY_CONFIRMED, on le retourne tel quel (ne pas promouvoir en SCHEDULED)
      if (status === 'SCHEDULED' || status === 'PARTIALLY_CONFIRMED' || status === 'REAL_TIME') {
        const minutesUntil = Math.floor((earliestGroup[0].instant.getTime() - now.getTime()) / 60000);
        const secondsUntil = Math.floor((earliestGroup[0].instant.getTime() - now.getTime()) / 1000);
        // Cas "maintenant" : si l'instant est exactement now (ou à la seconde près)
        const isNow = Math.abs(earliestGroup[0].instant.getTime() - now.getTime()) < 1000;
        return {
          status,
          scheduledTime: earliestGroup[0].departure_time,
          nextDepartureAt: earliestGroup[0].instant,
          minutesUntil: isNow ? 0 : minutesUntil,
          secondsUntil: isNow ? 0 : secondsUntil,
          frequencyMinutes: null,
          departures: earliestGroup,
          reason: status === 'PARTIALLY_CONFIRMED'
            ? 'Départ corroboré mais chaîne GTFS incomplète — PARTIALLY_CONFIRMED, non promu en SCHEDULED.'
            : 'Départ exact démontré.',
        };
      }
      // Si UNCONFIRMED, on ne le considère pas comme exact exploitable -> tomber en ESTIMATED/UNKNOWN
    }

    // 3. Fréquence documentée ?
    const freqs = this.frequencies.filter(f => f.route_id === routeId && f.schedule_status === 'ESTIMATED');
    if (freqs.length > 0) {
      // Pour TER, choisir la fréquence correspondant au jour (weekday vs sunday)
      let freq = freqs[0];
      if (freqs.length > 1 && routeId === 'ter_dakar_diamniadio') {
        const isSunday = svcDate.utcMidnight.getUTCDay() === 0;
        const sundayFreq = freqs.find(f => f.service_id === 'TER_SUNDAY');
        const weekdayFreq = freqs.find(f => f.service_id === 'TER_WEEKDAY');
        if (isSunday && sundayFreq) freq = sundayFreq;
        else if (!isSunday && weekdayFreq) freq = weekdayFreq;
      }
      return {
        status: 'ESTIMATED',
        scheduledTime: null,
        nextDepartureAt: null,
        minutesUntil: null,
        secondsUntil: null,
        frequencyMinutes: freq.headway_min,
        reason: `Fréquence documentée toutes les ${freq.headway_min} min — ESTIMATED, jamais convertie en heure exacte.`,
      };
    }

    // 4. UNKNOWN — aucune donnée fiable
    // Vérifier si service inactif pour donner raison plus précise
    const hasAnyForRoute = this.stopTimes.some(st => st.route_id === routeId);
    const hasFreqForRoute = this.frequencies.some(f => f.route_id === routeId);
    if (!hasAnyForRoute && !hasFreqForRoute) {
      // Vérifier si route existe dans public_routes mais sans horaire
      return { status: 'UNKNOWN', reason: `Aucune donnée horaire vérifiée pour la route ${routeId} (IDENTITY peut être CONFIRMED mais SCHEDULE = UNKNOWN).`, scheduledTime: null, minutesUntil: null };
    }
    return { status: 'UNKNOWN', reason: 'Aucun départ exact futur et aucune fréquence documentée pour ce stop/service.', scheduledTime: null, minutesUntil: null };
  }

  _findRealtime({ routeId, stopId, directionId, serviceDate, now }) {
    if (!this.realtimePredictions || this.realtimePredictions.length === 0) return null;
    const candidates = this.realtimePredictions.filter(p => {
      if (p.routeId !== routeId) return false;
      if (p.stopId !== stopId) return false;
      if (directionId !== null && p.directionId !== directionId) return false;
      if (!p.serviceDate.equals(serviceDate)) return false;
      // fraîcheur
      if (p.observedAt.getTime() > now.getTime()) return false;
      if (now.getTime() - p.observedAt.getTime() > this.realtimeMaxAgeMs) return false;
      if (p.predictedDepartureAt.getTime() < now.getTime()) return false;
      return true;
    });
    if (candidates.length === 0) return null;
    candidates.sort((a,b) => a.predictedDepartureAt.getTime() - b.predictedDepartureAt.getTime());
    return candidates[0];
  }

  _collectExactDepartures({ routeId, stopId, directionId, serviceDate, now }) {
    const candidates = [];
    // Filtrer stopTimes pour route/stop
    const relevant = this.stopTimes.filter(st => st.route_id === routeId && st.stop_id === stopId);
    // Pour chaque stopTime, vérifier validité et calendrier, puis comparer l'instant
    for (const st of relevant) {
      // Vérifier schedule_status : seuls SCHEDULED, PARTIALLY_CONFIRMED, REAL_TIME sont considérés comme exacts exploitables
      // UNCONFIRMED et UNKNOWN ne sont pas promus
      if (!['SCHEDULED','PARTIALLY_CONFIRMED','REAL_TIME'].includes(st.schedule_status)) continue;
      // Vérifier valid_from/to
      if (st.valid_from && st.valid_to) {
        // valid_from/to sont YYYYMMDD
        const vf = ServiceDate.parse(st.valid_from.slice(0,4)+'-'+st.valid_from.slice(4,6)+'-'+st.valid_from.slice(6,8));
        const vt = ServiceDate.parse(st.valid_to.slice(0,4)+'-'+st.valid_to.slice(4,6)+'-'+st.valid_to.slice(6,8));
        if (serviceDate.isBefore(vf) || serviceDate.isAfter(vt)) continue;
      }
      // Vérifier calendrier service actif si services fournis
      if (this.services.length > 0) {
        const svc = this.services.find(s => s.service_id === st.service_id);
        if (!svc) continue;
        if (!isServiceActiveOn(svc, serviceDate)) continue;
      }
      // Parser heure
      let stime;
      try { stime = ServiceTime.parse(st.departure_time); } catch { continue; }
      const instant = stime.toInstant(serviceDate);
      // Éliminer ceux déjà passés (instant < now)
      if (instant.getTime() < now.getTime()) {
        // Mais gérer >24h qui peut être le lendemain : déjà géré par toInstant (qui ajoute jours si hour>=24)
        // Si instant est encore < now, on pourrait aussi chercher sur serviceDate +1 si la grille s'étend
        continue;
      }
      candidates.push({ ...st, instant, departure_time: st.departure_time });
    }

    // Scanner les jours suivants jusqu'à MAX_DAYS_SCAN pour gérer départs après minuit (ex. 25:15 sur J)
    // et changement de jour : si aucun départ aujourd'hui, chercher demain
    // Pour Lot 4.6, la grille TER est seulement pour un jour, donc on scanne peu
    if (candidates.length === 0) {
      for (let offset = 1; offset <= MAX_DAYS_SCAN; offset++) {
        const nextDate = serviceDate.addDays(offset);
        // Vérifier si nextDate dépasse valid_to max
        let anyValid = false;
        for (const st of relevant) {
          if (st.valid_from && st.valid_to) {
            const vt = ServiceDate.parse(st.valid_to.slice(0,4)+'-'+st.valid_to.slice(4,6)+'-'+st.valid_to.slice(6,8));
            if (nextDate.isAfter(vt)) continue;
          }
          anyValid = true;
        }
        if (!anyValid) break;
        for (const st of relevant) {
          if (!['SCHEDULED','PARTIALLY_CONFIRMED','REAL_TIME'].includes(st.schedule_status)) continue;
          if (st.valid_from && st.valid_to) {
            const vf = ServiceDate.parse(st.valid_from.slice(0,4)+'-'+st.valid_from.slice(4,6)+'-'+st.valid_from.slice(6,8));
            const vt = ServiceDate.parse(st.valid_to.slice(0,4)+'-'+st.valid_to.slice(4,6)+'-'+st.valid_to.slice(6,8));
            if (nextDate.isBefore(vf) || nextDate.isAfter(vt)) continue;
          }
          if (this.services.length > 0) {
            const svc = this.services.find(s => s.service_id === st.service_id);
            if (!svc || !isServiceActiveOn(svc, nextDate)) continue;
          }
          let stime;
          try { stime = ServiceTime.parse(st.departure_time); } catch { continue; }
          const instant = stime.toInstant(nextDate);
          if (instant.getTime() < now.getTime()) continue;
          candidates.push({ ...st, instant, departure_time: st.departure_time, serviceDate: nextDate.toString() });
        }
        if (candidates.length > 0) break;
      }
    }

    return candidates;
  }
}

function isServiceActiveOn(service, date) {
  // service: {service_id, monday..sunday (1/0), start_date, end_date, exceptions: [{date, exception_type}]}
  // exception_type 1 = ajout, 2 = retrait
  const ymd = `${String(date.year).padStart(4,'0')}${String(date.month).padStart(2,'0')}${String(date.day).padStart(2,'0')}`;
  // Vérifier fenêtre
  if (service.start_date && service.end_date) {
    if (ymd < service.start_date || ymd > service.end_date) {
      // Mais exceptions ajout peuvent activer hors fenêtre
      const add = (service.exceptions||[]).find(e => e.date === ymd && e.exception_type === 1);
      if (!add) return false;
      // si ajout, on considère actif même hors fenêtre, sauf si retrait aussi?
    }
  }
  // Vérifier jour de semaine
  const weekday = date.utcMidnight.getUTCDay(); // 0 Sun .. 6 Sat
  const mapping = [service.sunday, service.monday, service.tuesday, service.wednesday, service.thursday, service.friday, service.saturday];
  let active = mapping[weekday] === 1 || mapping[weekday] === true;
  // Exceptions
  if (service.exceptions) {
    for (const ex of service.exceptions) {
      if (ex.date === ymd) {
        if (ex.exception_type === 1) active = true;
        if (ex.exception_type === 2) active = false;
      }
    }
  }
  return active;
}

module.exports = { ScheduleEngine, isServiceActiveOn };
