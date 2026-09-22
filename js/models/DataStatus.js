/**
 * Dakar Bus - Groupe 11
 * DataStatus : décrit la disponibilité / nature temporelle
 * Contrat validé Groupe 10H-C : ne pas modifier l'enum
 *
 * scheduled = horaire réellement sourcé
 * live      = donnée temps réel réellement sourcée
 * unknown   = aucune donnée temporelle exploitable
 */

export const DataStatus = Object.freeze({
  scheduled: 'scheduled',
  live: 'live',
  unknown: 'unknown',
});

/**
 * Validation helper - strict
 */
export function isValidDataStatus(value) {
  return Object.values(DataStatus).includes(value);
}

export default DataStatus;
