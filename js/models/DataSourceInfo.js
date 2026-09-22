/**
 * Dakar Bus - Groupe 11
 * DataSourceInfo : métadonnées sur la source d'un horaire
 * Ne contient aucune heure inventée.
 */

export class DataSourceInfo {
  /**
   * @param {Object} param0
   * @param {string} param0.sourceId - identifiant unique de la source (ex: gtfs-cetud-2026, api-ter-xxx)
   * @param {string} [param0.sourceType] - type : gtfs, api, file, realtime, etc.
   * @param {string} [param0.sourceName] - nom lisible
   * @param {Date|string|null} [param0.retrievedAt] - date de récupération
   * @param {string} [param0.trustLevel] - niveau de confiance (DataTrust)
   */
  constructor({ sourceId, sourceType = null, sourceName = null, retrievedAt = null, trustLevel = null } = {}) {
    if (!sourceId || typeof sourceId !== 'string') {
      throw new Error('DataSourceInfo requires a non-empty sourceId string');
    }
    this.sourceId = sourceId;
    this.sourceType = sourceType;
    this.sourceName = sourceName;
    this.retrievedAt = retrievedAt ? new Date(retrievedAt) : null;
    this.trustLevel = trustLevel;

    Object.freeze(this);
  }

  toString() {
    return `DataSourceInfo(${this.sourceId}, ${this.sourceType || 'unknown'})`;
  }
}

export default DataSourceInfo;
