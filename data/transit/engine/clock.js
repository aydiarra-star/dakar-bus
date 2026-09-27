'use strict';

/**
 * Lot 4.6 — Horloge injectable pour moteur horaire déterministe.
 *
 * Le moteur ne doit jamais appeler Date.now() directement.
 * L'instant courant est injecté sous forme de Clock afin de permettre
 * les tests déterministes et le rejeu.
 */

class SystemClock {
  now() {
    return new Date(); // UTC instant (Date is UTC internally)
  }
}

class FixedClock {
  /**
   * @param {Date|string} instant — instant UTC (Date ou ISO string)
   */
  constructor(instant) {
    if (typeof instant === 'string') {
      this._instant = new Date(instant);
    } else if (instant instanceof Date) {
      this._instant = new Date(instant.getTime());
    } else {
      throw new Error('FixedClock: instant must be Date or ISO string');
    }
    if (isNaN(this._instant.getTime())) throw new Error('FixedClock: invalid instant');
  }
  now() {
    return new Date(this._instant.getTime());
  }
}

module.exports = { SystemClock, FixedClock };
