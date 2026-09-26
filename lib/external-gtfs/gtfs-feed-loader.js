'use strict';
/**
 * Chargement d'un feed GTFS depuis un ZIP brut (lecture directe, aucune
 * extraction sur disque) ou depuis des textes (fixtures, assets).
 */
const path = require('path');
const { openZip, readTextEntry } = require('./zip-reader');
const { buildFeed, buildFeedFromTexts, validateFeed, ENGINE_TABLES, tableName } = require('./models');

/** Entrées .txt d'un ZIP (nom sans dossier ni extension → nom d'entrée). */
function gtfsEntries(zip) {
  const map = new Map();
  for (const e of zip.entries) {
    if (e.isDirectory || !/\.txt$/i.test(e.name)) continue;
    const base = tableName(path.posix.basename(e.name));
    if (!map.has(base)) map.set(base, e.name);
  }
  return map;
}

/**
 * Lit les tables utiles d'un ZIP (textes UTF-8, BOM retiré).
 * @param {string|object} zipOrPath chemin ou objet renvoyé par openZip
 * @param {string[]} [tables] tables à lire (défaut : ENGINE_TABLES)
 */
function readZipTables(zipOrPath, tables) {
  const zip = typeof zipOrPath === 'string' ? openZip(zipOrPath) : zipOrPath;
  const wanted = (tables || ENGINE_TABLES).map(tableName);
  const entries = gtfsEntries(zip);
  const texts = {};
  for (const t of wanted) {
    const entryName = entries.get(t);
    if (!entryName) continue;
    texts[t] = readTextEntry(zip, entryName);
  }
  return { zip, texts, files: Array.from(entries.keys()).sort(), entries };
}

/**
 * Charge un feed depuis un ZIP : { feed, validation, zip: {path,size,sha256}, files }.
 */
function loadFeedFromZip(zipOrPath, provenance, options = {}) {
  const { zip, texts, files } = readZipTables(zipOrPath, options.tables);
  const feed = buildFeed(texts, provenance, options);
  const validation = validateFeed(feed);
  return { feed, validation, files, zip: { path: zip.path, size: zip.size, sha256: zip.sha256, entries: zip.entries.map((e) => ({ name: e.name, size: e.uncompressedSize, crc32: e.crc32, lastModified: e.lastModified })) } };
}

/** Charge un feed depuis des textes ({ routes: '...', ... }). */
function loadFeedFromTexts(texts, provenance, options = {}) {
  const feed = buildFeedFromTexts(texts, provenance, options);
  return { feed, validation: validateFeed(feed), files: Array.from(feed.tables).sort() };
}

module.exports = { loadFeedFromZip, loadFeedFromTexts, readZipTables, gtfsEntries, buildFeedFromTexts };
