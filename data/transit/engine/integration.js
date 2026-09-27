'use strict';

/**
 * Lot 4.7 — Couche d'intégration du moteur horaire.
 *
 * Architecture :
 *   schedule_registry.json / public_routes.json (lecture seule)
 *          ↓
 *   ScheduleEngine (pur, Clock injecté)
 *          ↓
 *   DepartureInfo-like contract (status, routeId, stopId, serviceDate, scheduledTime, nextDepartureAt, frequencyMinutes, source, sourceType, confidence, verificationNote)
 *
 * Ne réécrit jamais schedule_registry.json ni public_routes.json.
 * Ne transforme jamais une fréquence en heures exactes.
 * Ne promeut jamais PARTIALLY_CONFIRMED en SCHEDULED.
 */

const fs = require('fs');
const path = require('path');
const { ScheduleEngine } = require('./schedule_engine');
const { ServiceDate } = require('./gtfs_time');

const DEFAULT_REGISTRY_PATH = path.join(__dirname, '..', 'validated', 'schedule_registry.json');
const DEFAULT_PUBLIC_ROUTES_PATH = path.join(__dirname, '..', 'validated', 'public_routes.json');

/**
 * Charge le registre horaire (lecture seule).
 */
function loadRegistry(registryPath = DEFAULT_REGISTRY_PATH) {
  const raw = fs.readFileSync(registryPath, 'utf8');
  return JSON.parse(raw);
}

/**
 * Adaptateur qui transforme le résultat du ScheduleEngine en contrat de sortie
 * consommable par Flutter (DepartureInfo-like).
 *
 * @param {Object} engineResult — retour de ScheduleEngine.nextDeparture
 * @param {Object} req — requête d'origine
 * @returns {Object} contrat
 */
function toContract(engineResult, req) {
  const base = {
    status: engineResult.status,
    routeId: req.routeId,
    stopId: req.stopId,
    serviceDate: req.serviceDate instanceof ServiceDate ? req.serviceDate.toString() : req.serviceDate,
    scheduledTime: engineResult.scheduledTime || null,
    nextDepartureAt: engineResult.nextDepartureAt ? engineResult.nextDepartureAt.toISOString() : null,
    frequencyMinutes: engineResult.frequencyMinutes || null,
    source: null,
    sourceType: null,
    confidence: null,
    verificationNote: engineResult.reason || null,
    minutesUntil: engineResult.minutesUntil ?? null,
    secondsUntil: engineResult.secondsUntil ?? null,
  };

  // Enrichir avec source si disponible (pour ESTIMATED, on a la fréquence)
  if (engineResult.status === 'ESTIMATED') {
    base.source = 'frequency';
    base.sourceType = 'OFFICIAL_OPERATOR';
  } else if (engineResult.departures && engineResult.departures.length > 0) {
    const dep = engineResult.departures[0];
    base.source = dep.source || null;
    base.sourceType = dep.source_type || null;
    base.confidence = dep.confidence || null;
    base.verificationNote = dep.verification_note || base.verificationNote;
  }

  // Label d'affichage conceptuel (pas visuel, mais pour future UI)
  if (base.status === 'SCHEDULED' || base.status === 'PARTIALLY_CONFIRMED') {
    if (base.minutesUntil === 0) base.displayLabel = 'Départ maintenant';
    else if (base.minutesUntil !== null) base.displayLabel = `Départ dans ${base.minutesUntil} min`;
  } else if (base.status === 'REAL_TIME') {
    if (base.minutesUntil === 0) base.displayLabel = 'Arrivée imminente';
    else base.displayLabel = `Arrivée dans ${base.minutesUntil} min`;
  } else if (base.status === 'ESTIMATED') {
    base.displayLabel = `Passage estimé toutes les ${base.frequencyMinutes} min`;
  } else {
    base.displayLabel = 'Horaire indisponible';
  }

  // Garantie : ESTIMATED n'a jamais scheduledTime / nextDepartureAt
  if (base.status === 'ESTIMATED') {
    base.scheduledTime = null;
    base.nextDepartureAt = null;
  }

  return base;
}

/**
 * Fabrique un moteur câblé sur le registre réel du dépôt.
 * @param {string} registryPath — optionnel, chemin vers schedule_registry.json
 * @returns {ScheduleEngine}
 */
function createEngineFromRegistry(registryPath) {
  const registry = loadRegistry(registryPath);
  return ScheduleEngine.fromRegistry(registry);
}

/**
 * Requête haut niveau : route/stop/serviceDate/now → contrat.
 * @param {Object} req
 * @param {string} req.routeId
 * @param {string} req.stopId
 * @param {string} req.serviceDate — "YYYY-MM-DD"
 * @param {Date} req.now — instant UTC
 * @param {ScheduleEngine} req.engine — optionnel, sinon créé depuis le registre
 * @returns {Object} contrat
 */
function queryDeparture({ routeId, stopId, serviceDate, now, engine, directionId = null }) {
  const eng = engine || createEngineFromRegistry();
  const result = eng.nextDeparture({ routeId, stopId, directionId, serviceDate, now });
  return toContract(result, { routeId, stopId, serviceDate, now });
}

module.exports = { loadRegistry, toContract, createEngineFromRegistry, queryDeparture };
