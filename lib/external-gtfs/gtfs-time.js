'use strict';
/**
 * Heures et dates GTFS. Aucun arrondi, aucune heure fabriquée : une heure est
 * soit lue telle quelle dans stop_times.txt, soit absente.
 *
 * Fuseau de service : Africa/Dakar = UTC+0 toute l'année (pas d'heure d'été).
 */

const TIME_RE = /^\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$/;

/** 'HH:MM[:SS]' (HH peut dépasser 24 en GTFS) → secondes depuis minuit, ou null. */
function parseTime(value) {
  if (value === null || value === undefined) return null;
  const m = TIME_RE.exec(String(value));
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  const s = m[3] === undefined ? 0 : Number(m[3]);
  if (min > 59 || s > 59) return null;
  return h * 3600 + min * 60 + s;
}

const pad2 = (n) => String(n).padStart(2, '0');

/** secondes → 'HH:MM:SS' (HH non réduit modulo 24, conforme GTFS). */
function formatTime(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${pad2(h)}:${pad2(m)}:${pad2(s)}`;
}

/** secondes → 'HH:MM' (affichage). */
function formatHHMM(seconds) {
  return `${pad2(Math.floor(seconds / 3600))}:${pad2(Math.floor((seconds % 3600) / 60))}`;
}

/** 'YYYY-MM-DD' | 'YYYYMMDD' → 'YYYYMMDD' ; lève si invalide. */
function normalizeServiceDate(value) {
  const s = String(value === undefined || value === null ? '' : value).trim();
  let m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) m = /^(\d{4})(\d{2})(\d{2})$/.exec(s);
  if (!m) throw new Error(`Date de service invalide : « ${value} »`);
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  const dt = new Date(Date.UTC(y, mo - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) {
    throw new Error(`Date de service inexistante : « ${value} »`);
  }
  return `${m[1]}${m[2]}${m[3]}`;
}

/** 'YYYYMMDD' → 'YYYY-MM-DD'. */
function toIsoDate(yyyymmdd) {
  const s = normalizeServiceDate(yyyymmdd);
  return `${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}`;
}

const WEEKDAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

/** Jour de semaine GTFS ('monday'…'sunday') d'une date 'YYYYMMDD'. */
function weekdayOf(yyyymmdd) {
  const s = normalizeServiceDate(yyyymmdd);
  const dt = new Date(Date.UTC(Number(s.slice(0, 4)), Number(s.slice(4, 6)) - 1, Number(s.slice(6, 8))));
  return WEEKDAYS[dt.getUTCDay()];
}

/** Date 'YYYYMMDD' + n jours. */
function addDays(yyyymmdd, n) {
  const s = normalizeServiceDate(yyyymmdd);
  const dt = new Date(Date.UTC(Number(s.slice(0, 4)), Number(s.slice(4, 6)) - 1, Number(s.slice(6, 8)) + n));
  return `${dt.getUTCFullYear()}${pad2(dt.getUTCMonth() + 1)}${pad2(dt.getUTCDate())}`;
}

/** Comparaison lexicale de deux dates 'YYYYMMDD' (négatif, 0, positif). */
function compareDates(a, b) {
  const x = normalizeServiceDate(a);
  const y = normalizeServiceDate(b);
  return x < y ? -1 : x > y ? 1 : 0;
}

/**
 * Horloge de Dakar (UTC+0) pour un instant donné : jour de service et heure.
 * @param {Date} instant
 */
function dakarClock(instant) {
  const d = instant instanceof Date ? instant : new Date(instant);
  if (Number.isNaN(d.getTime())) throw new Error('Instant invalide');
  const seconds = d.getUTCHours() * 3600 + d.getUTCMinutes() * 60 + d.getUTCSeconds();
  return {
    serviceDate: `${d.getUTCFullYear()}${pad2(d.getUTCMonth() + 1)}${pad2(d.getUTCDate())}`,
    isoDate: `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`,
    seconds,
    time: formatTime(seconds),
  };
}

module.exports = {
  parseTime, formatTime, formatHHMM, normalizeServiceDate, toIsoDate, weekdayOf, addDays, compareDates, dakarClock, WEEKDAYS,
};
