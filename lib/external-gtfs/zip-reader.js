'use strict';
/**
 * Lecteur ZIP minimal, sans dépendance (Node ≥ 18) : lit le répertoire central
 * d'une archive et décompresse une entrée à la demande (stored ou deflate).
 *
 * Objectif LOT 18 BIS : lire les feeds GTFS DIRECTEMENT depuis les ZIP bruts
 * (PassBi : audit/external-feeds/source/passbi_core/gtfs_folder/*.zip ; CETUD :
 * ZIP officiel reçu) sans extraire des dizaines de Mo de .txt dans Git.
 * Le ZIP n'est jamais modifié ; seules des lectures sont effectuées.
 */
const fs = require('fs');
const zlib = require('zlib');
const crypto = require('crypto');

const SIG_EOCD = 0x06054b50;
const SIG_CENTRAL = 0x02014b50;
const SIG_LOCAL = 0x04034b50;

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function findEndOfCentralDirectory(buf) {
  const minPos = Math.max(0, buf.length - 0xffff - 22);
  for (let pos = buf.length - 22; pos >= minPos; pos--) {
    if (buf.readUInt32LE(pos) === SIG_EOCD) return pos;
  }
  throw new Error('ZIP invalide : fin de répertoire central introuvable');
}

/**
 * Liste les entrées du ZIP (nom, tailles, méthode, CRC, offset local).
 * @param {Buffer} buf contenu complet de l'archive
 */
function listEntries(buf) {
  if (!Buffer.isBuffer(buf)) throw new TypeError('listEntries attend un Buffer');
  if (buf.length < 22) throw new Error('ZIP invalide : archive trop courte');
  const eocd = findEndOfCentralDirectory(buf);
  const entryCount = buf.readUInt16LE(eocd + 10);
  const centralSize = buf.readUInt32LE(eocd + 12);
  const centralOffset = buf.readUInt32LE(eocd + 16);
  if (entryCount === 0xffff || centralSize === 0xffffffff || centralOffset === 0xffffffff) {
    throw new Error('ZIP64 non pris en charge');
  }
  if (centralOffset + centralSize > buf.length) throw new Error('ZIP invalide : répertoire central hors de l\'archive');
  const entries = [];
  let pos = centralOffset;
  for (let i = 0; i < entryCount; i++) {
    if (buf.readUInt32LE(pos) !== SIG_CENTRAL) throw new Error(`ZIP invalide : signature de répertoire central absente (entrée ${i})`);
    const flags = buf.readUInt16LE(pos + 8);
    const method = buf.readUInt16LE(pos + 10);
    const crc32 = buf.readUInt32LE(pos + 16);
    const compressedSize = buf.readUInt32LE(pos + 20);
    const uncompressedSize = buf.readUInt32LE(pos + 24);
    const nameLength = buf.readUInt16LE(pos + 28);
    const extraLength = buf.readUInt16LE(pos + 30);
    const commentLength = buf.readUInt16LE(pos + 32);
    const localOffset = buf.readUInt32LE(pos + 42);
    const name = buf.toString('utf8', pos + 46, pos + 46 + nameLength);
    const dosTime = buf.readUInt16LE(pos + 12);
    const dosDate = buf.readUInt16LE(pos + 14);
    entries.push({
      name,
      method,
      flags,
      crc32,
      compressedSize,
      uncompressedSize,
      localOffset,
      encrypted: (flags & 0x1) !== 0,
      isDirectory: name.endsWith('/'),
      lastModified: dosDateTimeToIso(dosDate, dosTime),
    });
    pos += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}

function dosDateTimeToIso(dosDate, dosTime) {
  const year = ((dosDate >> 9) & 0x7f) + 1980;
  const month = (dosDate >> 5) & 0x0f;
  const day = dosDate & 0x1f;
  const hour = (dosTime >> 11) & 0x1f;
  const minute = (dosTime >> 5) & 0x3f;
  const second = (dosTime & 0x1f) * 2;
  const p = (n) => String(n).padStart(2, '0');
  return `${year}-${p(month)}-${p(day)}T${p(hour)}:${p(minute)}:${p(second)}`;
}

/**
 * Décompresse une entrée. Vérifie la taille et le CRC-32 : une archive
 * corrompue est refusée plutôt que lue partiellement.
 * @param {Buffer} buf archive complète
 * @param {string|object} entryOrName nom d'entrée (sensible à la casse) ou entrée de listEntries
 * @returns {Buffer}
 */
function readEntry(buf, entryOrName, entries) {
  const list = entries || listEntries(buf);
  const entry = typeof entryOrName === 'string' ? list.find((e) => e.name === entryOrName) : entryOrName;
  if (!entry) throw new Error(`Entrée absente du ZIP : ${entryOrName}`);
  if (entry.encrypted) throw new Error(`Entrée chiffrée non prise en charge : ${entry.name}`);
  const lp = entry.localOffset;
  if (lp + 30 > buf.length || buf.readUInt32LE(lp) !== SIG_LOCAL) throw new Error(`ZIP invalide : en-tête local absent pour ${entry.name}`);
  const nameLength = buf.readUInt16LE(lp + 26);
  const extraLength = buf.readUInt16LE(lp + 28);
  const start = lp + 30 + nameLength + extraLength;
  const end = start + entry.compressedSize;
  if (end > buf.length) throw new Error(`ZIP invalide : données tronquées pour ${entry.name}`);
  const raw = buf.subarray(start, end);
  let data;
  if (entry.method === 0) data = Buffer.from(raw);
  else if (entry.method === 8) data = zlib.inflateRawSync(raw);
  else throw new Error(`Méthode de compression ${entry.method} non prise en charge (${entry.name})`);
  if (data.length !== entry.uncompressedSize) {
    throw new Error(`ZIP invalide : taille décompressée ${data.length} ≠ ${entry.uncompressedSize} (${entry.name})`);
  }
  if (typeof zlib.crc32 === 'function') {
    const crc = zlib.crc32(data) >>> 0;
    if (crc !== (entry.crc32 >>> 0)) throw new Error(`ZIP invalide : CRC-32 incorrect (${entry.name})`);
  }
  return data;
}

/** Ouvre un ZIP depuis le disque : { path, buffer, size, sha256, entries }. */
function openZip(zipPath) {
  const buffer = fs.readFileSync(zipPath);
  return { path: zipPath, buffer, size: buffer.length, sha256: sha256(buffer), entries: listEntries(buffer) };
}

/** Lit une entrée texte (UTF-8, BOM retiré) ou renvoie null si absente. */
function readTextEntry(zip, name) {
  const entry = zip.entries.find((e) => e.name === name);
  if (!entry) return null;
  let text = readEntry(zip.buffer, entry, zip.entries).toString('utf8');
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
  return text;
}

module.exports = { listEntries, readEntry, openZip, readTextEntry, sha256 };
