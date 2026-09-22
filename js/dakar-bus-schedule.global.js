/**
 * Dakar Bus - Groupe 11
 * Socle horaires réels - Version globale pour navigateur (sans ESM)
 * Expose window.DakarBusSchedule
 *
 * Respecte règle absolue : pas de donnée inventée
 */

(function (global) {
  // DataStatus - contrat validé Groupe 10H-C
  const DataStatus = Object.freeze({
    scheduled: 'scheduled',
    live: 'live',
    unknown: 'unknown',
  });

  const DataTrust = Object.freeze({
    verified: 'verified',
    official: 'official',
    community: 'community',
    unknown: 'unknown',
  });

  // DataSourceInfo
  class DataSourceInfo {
    constructor({ sourceId, sourceType = null, sourceName = null, retrievedAt = null, trustLevel = null } = {}) {
      if (!sourceId || typeof sourceId !== 'string') {
        throw new Error('DataSourceInfo requires sourceId');
      }
      this.sourceId = sourceId;
      this.sourceType = sourceType;
      this.sourceName = sourceName;
      this.retrievedAt = retrievedAt ? new Date(retrievedAt) : null;
      this.trustLevel = trustLevel;
      Object.freeze(this);
    }
  }

  // Departure - modèle minimal, immutable, pas de valeur calculée arbitrairement
  class Departure {
    constructor({ stopId, lineId, departureTime, status, direction = null, sourceId = null }) {
      if (!stopId || typeof stopId !== 'string') throw new Error('Departure requires stopId');
      if (!lineId || typeof lineId !== 'string') throw new Error('Departure requires lineId');
      if (!(departureTime instanceof Date) || isNaN(departureTime.getTime())) {
        throw new Error('Departure requires valid Date departureTime from real source');
      }
      if (!Object.values(DataStatus).includes(status)) {
        throw new Error('Invalid DataStatus');
      }
      this.stopId = stopId;
      this.lineId = lineId;
      this.departureTime = new Date(departureTime.getTime());
      this.status = status;
      this.direction = direction;
      this.sourceId = sourceId;
      Object.freeze(this);
    }

    isFuture(now = new Date()) {
      return this.departureTime.getTime() > now.getTime();
    }

    remainingMinutes(now = new Date()) {
      const diff = this.departureTime.getTime() - now.getTime();
      if (diff <= 0) return null;
      return Math.floor(diff / 60000);
    }
  }

  // ScheduleRepository abstraction
  class ScheduleRepository {
    async departuresForStop(stopId) {
      throw new Error('must be implemented');
    }
    async departuresForStopAndLine(stopId, lineId) {
      const all = await this.departuresForStop(stopId);
      return all.filter(d => d.lineId === lineId);
    }
  }

  // UnavailableScheduleRepository - aucune source réelle branchée
  class UnavailableScheduleRepository extends ScheduleRepository {
    async departuresForStop(stopId) {
      return []; // volontairement vide, pas de génération
    }
  }

  // Stop enrichi
  class Stop {
    constructor({ id, name, lat = null, lng = null, lines = [], type = null, departures = [], trust = DataTrust.unknown, raw = null }) {
      if (!id || typeof id !== 'string') throw new Error('Stop requires id');
      if (!name || typeof name !== 'string') throw new Error('Stop requires name');
      this.id = id;
      this.name = name;
      this.lat = lat;
      this.lng = lng;
      this.lines = Array.isArray(lines) ? [...lines] : [];
      this.type = type;
      this.trust = trust;
      this.raw = raw;
      this._departures = Array.isArray(departures) ? [...departures] : [];
    }

    get departures() {
      return [...this._departures];
    }

    setDepartures(departures) {
      if (!Array.isArray(departures)) throw new Error('array required');
      this._departures = [...departures];
    }

    get hasSourcedSchedule() {
      return this._departures.length > 0;
    }

    get dataStatus() {
      if (!this.hasSourcedSchedule) return DataStatus.unknown;
      const next = this.departureAfter(new Date());
      if (!next) return DataStatus.unknown;
      return next.status;
    }

    departureAfter(after = new Date()) {
      if (!(after instanceof Date) || isNaN(after.getTime())) throw new Error('valid Date required');
      if (this._departures.length === 0) return null;
      const future = this._departures
        .filter(d => d.departureTime.getTime() > after.getTime())
        .sort((a, b) => a.departureTime.getTime() - b.departureTime.getTime());
      return future.length ? future[0] : null;
    }

    remainingMinutes(now = new Date()) {
      const next = this.departureAfter(now);
      if (!next) return null;
      const diff = next.departureTime.getTime() - now.getTime();
      if (diff <= 0) return null;
      return Math.floor(diff / 60000);
    }

    nextDepartureLabel(now = new Date()) {
      const next = this.departureAfter(now);
      if (!next) return 'Horaire non disponible';
      const h = next.departureTime.getHours();
      const m = next.departureTime.getMinutes().toString().padStart(2, '0');
      return `${h} h ${m}`;
    }

    _generateSchedule() {
      console.warn('_generateSchedule deprecated, must not be used as real source');
      return [];
    }
  }

  // Services
  function departureAfter(departures, after = new Date()) {
    if (!Array.isArray(departures) || departures.length === 0) return null;
    const future = departures
      .filter(d => d.departureTime.getTime() > after.getTime())
      .sort((a, b) => a.departureTime.getTime() - b.departureTime.getTime());
    return future.length ? future[0] : null;
  }

  function remainingMinutes(departures, now = new Date()) {
    const next = departureAfter(departures, now);
    if (!next) return null;
    const diff = next.departureTime.getTime() - now.getTime();
    if (diff <= 0) return null;
    return Math.floor(diff / 60000);
  }

  function nextDepartureLabel(departures, now = new Date()) {
    const next = departureAfter(departures, now);
    if (!next) return 'Horaire non disponible';
    const h = next.departureTime.getHours();
    const m = next.departureTime.getMinutes().toString().padStart(2, '0');
    return `${h} h ${m}`;
  }

  function getDataStatus(departures, now = new Date()) {
    const next = departureAfter(departures, now);
    if (!next) return DataStatus.unknown;
    return next.status;
  }

  function hasSourcedSchedule(departures) {
    return Array.isArray(departures) && departures.length > 0;
  }

  // Expose global
  const DakarBusSchedule = {
    DataStatus,
    DataTrust,
    DataSourceInfo,
    Departure,
    Stop,
    ScheduleRepository,
    UnavailableScheduleRepository,
    services: {
      departureAfter,
      remainingMinutes,
      nextDepartureLabel,
      getDataStatus,
      hasSourcedSchedule,
    },
    // Instance par défaut : aucune source réelle branchée
    defaultRepository: new UnavailableScheduleRepository(),
    // Helper pour intégration UI existante
    getLabelForStop: function (stopObj, now = new Date()) {
      // stopObj peut être ancien format avec .next ou nouveau Stop
      if (stopObj instanceof Stop) {
        return stopObj.nextDepartureLabel(now);
      }
      if (stopObj && Array.isArray(stopObj.departures) && stopObj.departures.length > 0) {
        return nextDepartureLabel(stopObj.departures, now);
      }
      // Ancien format sans source réelle -> Horaire non disponible (règle Groupe 11)
      return 'Horaire non disponible';
    }
  };

  global.DakarBusSchedule = DakarBusSchedule;

  // ESM-like export for module loaders if needed
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = DakarBusSchedule;
  }

})(typeof window !== 'undefined' ? window : globalThis);
