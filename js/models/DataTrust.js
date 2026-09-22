/**
 * Dakar Bus - Groupe 11
 * DataTrust : décrit la confiance / nature de la donnée
 * Ne pas confondre avec DataStatus
 *
 * DataStatus = disponibilité/nature temporelle (scheduled/live/unknown)
 * DataTrust  = confiance / provenance / qualité
 */

export const DataTrust = Object.freeze({
  verified: 'verified',       // source officielle vérifiée
  official: 'official',       // source officielle non encore vérifiée terrain
  community: 'community',     // contribution communautaire
  unknown: 'unknown',         // confiance inconnue
});

export function isValidDataTrust(value) {
  return Object.values(DataTrust).includes(value);
}

export default DataTrust;
