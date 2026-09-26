'use strict';
/**
 * Provenance et validité d'un feed externe. Règles :
 *  - un feed est CURRENT uniquement si sa fenêtre de validité couvre la date
 *    interrogée ET que son statut déclaré (manifeste) le permet ; le statut
 *    déclaré ne peut jamais être amélioré par le calcul (HISTORICAL reste
 *    HISTORICAL même si les dates internes couvrent la date) ;
 *  - `retrieved_at` seul ne prouve rien.
 */
const { normalizeServiceDate, toIsoDate } = require('./gtfs-time');

/** Catégories de source (qui publie). */
const SOURCE_TYPES = Object.freeze({
  SOURCE_INSTITUTIONAL: 'SOURCE_INSTITUTIONAL', // CETUD ou autre autorité / opérateur officiel
  SOURCE_APPLICATION: 'SOURCE_APPLICATION', // application tierce (PassBi)
  OPEN_DATA: 'OPEN_DATA',
  COMMUNITY: 'COMMUNITY', // jamais officiel
  UNKNOWN: 'UNKNOWN',
});

/** Libellés de manifeste → catégorie. */
const SOURCE_TYPE_LABELS = Object.freeze({
  OFFICIAL_STATIC_CURRENT: SOURCE_TYPES.SOURCE_INSTITUTIONAL,
  OFFICIAL_STATIC: SOURCE_TYPES.SOURCE_INSTITUTIONAL,
  OFFICIAL_CURRENT: SOURCE_TYPES.SOURCE_INSTITUTIONAL,
  SOURCE_INSTITUTIONAL: SOURCE_TYPES.SOURCE_INSTITUTIONAL,
  SOURCE_APPLICATION: SOURCE_TYPES.SOURCE_APPLICATION,
  SOURCE_APPLICATION_CURRENT: SOURCE_TYPES.SOURCE_APPLICATION,
  OPEN_DATA: SOURCE_TYPES.OPEN_DATA,
  OPEN_DATA_CURRENT: SOURCE_TYPES.OPEN_DATA,
  COMMUNITY: SOURCE_TYPES.COMMUNITY,
});

const VALIDITY = Object.freeze({ CURRENT: 'CURRENT', HISTORICAL: 'HISTORICAL', FUTURE: 'FUTURE', UNKNOWN: 'UNKNOWN' });

/** Niveaux de provenance d'une réponse horaire (du plus au moins fiable). */
const PROVENANCE_LEVELS = Object.freeze([
  'OFFICIAL_CURRENT', // CETUD / officiel avec temps réel prouvé
  'OFFICIAL_STATIC_CURRENT', // CETUD / officiel statique actuel
  'SOURCE_APPLICATION_CURRENT', // PassBi CURRENT réellement prouvé
  'OPEN_DATA_CURRENT',
  'ESTIMATED', // fréquence documentée, sans horaire précis
  'HISTORICAL_REFERENCE',
  'UNKNOWN',
]);

/** Statut de validité d'une fenêtre [validFrom, validTo] à une date. */
function classifyValidity(validFrom, validTo, asOf) {
  if (!validFrom || !validTo) return VALIDITY.UNKNOWN;
  let from; let to; let day;
  try {
    from = normalizeServiceDate(validFrom);
    to = normalizeServiceDate(validTo);
    day = normalizeServiceDate(asOf);
  } catch (e) {
    return VALIDITY.UNKNOWN;
  }
  if (from > to) return VALIDITY.UNKNOWN;
  if (day < from) return VALIDITY.FUTURE;
  if (day > to) return VALIDITY.HISTORICAL;
  return VALIDITY.CURRENT;
}

class FeedProvenance {
  /**
   * @param {object} p
   * @param {string} p.source ex. 'PassBi', 'CETUD'
   * @param {string} p.sourceType libellé (OFFICIAL_STATIC_CURRENT, SOURCE_APPLICATION, …)
   * @param {string} p.feedVersion
   * @param {string} p.validFrom 'YYYY-MM-DD'
   * @param {string} p.validTo 'YYYY-MM-DD'
   * @param {string} p.declaredStatus CURRENT | HISTORICAL | FUTURE | UNKNOWN (manifeste)
   */
  constructor(p) {
    if (!p || !p.source) throw new Error('FeedProvenance : source obligatoire');
    this.source = p.source;
    this.sourceTypeLabel = p.sourceType || 'UNKNOWN';
    this.sourceType = SOURCE_TYPE_LABELS[this.sourceTypeLabel] || SOURCE_TYPES.UNKNOWN;
    this.feedVersion = p.feedVersion || '';
    this.validFrom = p.validFrom || null;
    this.validTo = p.validTo || null;
    this.declaredStatus = VALIDITY[p.declaredStatus] ? p.declaredStatus : VALIDITY.UNKNOWN;
    this.authority = p.authority || null;
    this.sourceId = p.sourceId || `${this.source}:${this.feedVersion}`;
    this.network = p.network || null;
    this.role = p.role || null;
    this.license = p.license || null;
    this.url = p.url || null;
    this.sha256 = p.sha256 || null;
    this.originalFile = p.originalFile || null;
    this.retrievedAt = p.retrievedAt || null;
    this.publishedAt = p.publishedAt || null;
    Object.freeze(this);
  }

  /** Statut à une date : jamais meilleur que le statut déclaré. */
  validityStatusOn(asOf) {
    const computed = classifyValidity(this.validFrom, this.validTo, asOf);
    if (this.declaredStatus === VALIDITY.HISTORICAL) return VALIDITY.HISTORICAL;
    if (this.declaredStatus === VALIDITY.UNKNOWN) return computed === VALIDITY.CURRENT ? VALIDITY.UNKNOWN : computed;
    return computed;
  }

  isCurrentOn(asOf) { return this.validityStatusOn(asOf) === VALIDITY.CURRENT; }

  /** La fenêtre couvre la date (indépendamment du statut déclaré). */
  coversDate(date) { return classifyValidity(this.validFrom, this.validTo, date) === VALIDITY.CURRENT; }

  validityOn(asOf, queryDate) {
    return {
      validFrom: this.validFrom,
      validTo: this.validTo,
      status: this.validityStatusOn(asOf),
      asOf: safeIso(asOf),
      coversQueryDate: queryDate ? this.coversDate(queryDate) : null,
    };
  }

  toJSON() {
    return {
      source: this.source, source_type: this.sourceTypeLabel, source_category: this.sourceType, feed_version: this.feedVersion,
      valid_from: this.validFrom, valid_to: this.validTo, status: this.declaredStatus, authority: this.authority,
      id: this.sourceId, network: this.network, role: this.role, license: this.license, url: this.url, sha256: this.sha256,
      retrieved_at: this.retrievedAt, published_at: this.publishedAt,
    };
  }

  /** Construit la provenance depuis une entrée de feed-manifest.json. */
  static fromManifestEntry(entry) {
    return new FeedProvenance({
      source: entry.source,
      sourceType: entry.source_type,
      feedVersion: entry.feed_version || entry.version || '',
      validFrom: entry.valid_from || null,
      validTo: entry.valid_to || null,
      declaredStatus: entry.status,
      authority: entry.authority || null,
      sourceId: entry.id || null,
      network: entry.network || null,
      role: entry.role || null,
      license: entry.license || null,
      url: entry.url || null,
      sha256: entry.sha256 || null,
      originalFile: entry.original_file || entry.zip || null,
      retrievedAt: entry.retrieved_at || null,
      publishedAt: entry.published_at || null,
    });
  }
}

function safeIso(v) {
  try { return toIsoDate(v); } catch (e) { return null; }
}

module.exports = { FeedProvenance, classifyValidity, SOURCE_TYPES, SOURCE_TYPE_LABELS, VALIDITY, PROVENANCE_LEVELS };
