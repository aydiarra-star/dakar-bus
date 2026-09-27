'use strict';

/**
 * Lot 4.6 — ServiceDate / ServiceTime — convention GTFS >24h conservée.
 *
 * Ne jamais réécrire 25:15:00 → 01:15:00. Les heures >=24 sont conservées
 * et comparées correctement via secondsSinceServiceDayStart.
 */

class ServiceDate {
  constructor(year, month, day) {
    if (!Number.isInteger(year) || year < 1 || year > 9999) throw new Error(`ServiceDate: year invalide ${year}`);
    // Validate via UTC
    const candidate = new Date(Date.UTC(year + 400, month - 1, day));
    if (candidate.getUTCFullYear() !== year + 400 || candidate.getUTCMonth() !== month - 1 || candidate.getUTCDate() !== day) {
      throw new Error(`ServiceDate invalide: ${year}-${month}-${day}`);
    }
    this.year = year;
    this.month = month;
    this.day = day;
  }

  static parse(iso) {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
    if (!m) throw new Error(`ServiceDate.parse: format ISO invalide ${iso}`);
    return new ServiceDate(parseInt(m[1],10), parseInt(m[2],10), parseInt(m[3],10));
  }

  static fromInstant(instant) {
    const d = instant instanceof Date ? instant : new Date(instant);
    return new ServiceDate(d.getUTCFullYear(), d.getUTCMonth()+1, d.getUTCDate());
  }

  get utcMidnight() {
    return new Date(Date.UTC(this.year, this.month-1, this.day, 0,0,0,0));
  }

  get weekday() {
    return this.utcMidnight.getUTCDay(); // 0 Sun .. 6 Sat ; GTFS weekday uses 1 Mon .. 7 Sun but we use JS
  }

  addDays(n) {
    const next = new Date(this.utcMidnight.getTime() + n*24*3600*1000);
    return new ServiceDate(next.getUTCFullYear(), next.getUTCMonth()+1, next.getUTCDate());
  }

  isBefore(other) { return this.compareTo(other) < 0; }
  isAfter(other) { return this.compareTo(other) > 0; }
  compareTo(other) {
    if (this.year !== other.year) return this.year - other.year;
    if (this.month !== other.month) return this.month - other.month;
    return this.day - other.day;
  }
  equals(other) { return other instanceof ServiceDate && this.year===other.year && this.month===other.month && this.day===other.day; }
  toString() {
    return `${String(this.year).padStart(4,'0')}-${String(this.month).padStart(2,'0')}-${String(this.day).padStart(2,'0')}`;
  }
}

class ServiceTime {
  constructor(hour, minute, second) {
    if (!Number.isInteger(hour) || hour < 0) throw new Error(`ServiceTime hour invalide ${hour}`);
    if (!Number.isInteger(minute) || minute <0 || minute>59) throw new Error(`ServiceTime minute invalide ${minute}`);
    if (!Number.isInteger(second) || second <0 || second>59) throw new Error(`ServiceTime second invalide ${second}`);
    this.hour = hour;
    this.minute = minute;
    this.second = second;
  }

  static parse(gtfs) {
    const m = /^(\d{1,3}):([0-5]\d):([0-5]\d)$/.exec(gtfs);
    if (!m) throw new Error(`ServiceTime.parse invalide ${gtfs}`);
    return new ServiceTime(parseInt(m[1],10), parseInt(m[2],10), parseInt(m[3],10));
  }

  get secondsSinceServiceDayStart() {
    return this.hour*3600 + this.minute*60 + this.second;
  }

  toInstant(serviceDate) {
    return new Date(serviceDate.utcMidnight.getTime() + this.secondsSinceServiceDayStart*1000);
  }

  civilDate(serviceDate) {
    const days = Math.floor(this.secondsSinceServiceDayStart / (24*3600));
    return serviceDate.addDays(days);
  }

  compareTo(other) {
    return this.secondsSinceServiceDayStart - other.secondsSinceServiceDayStart;
  }

  toString() {
    return `${String(this.hour).padStart(2,'0')}:${String(this.minute).padStart(2,'0')}:${String(this.second).padStart(2,'0')}`;
  }
}

function isValidGTFSDate(yyyymmdd) {
  if (!/^\d{8}$/.test(yyyymmdd)) return false;
  const y = parseInt(yyyymmdd.slice(0,4),10);
  const m = parseInt(yyyymmdd.slice(4,6),10);
  const d = parseInt(yyyymmdd.slice(6,8),10);
  try { new ServiceDate(y,m,d); return true; } catch { return false; }
}

function isValidGTFSTime(t) {
  try { ServiceTime.parse(t); return true; } catch { return false; }
}

module.exports = { ServiceDate, ServiceTime, isValidGTFSDate, isValidGTFSTime };
