'use strict';
/**
 * Analyseur CSV pour fichiers GTFS : RFC 4180 (guillemets, guillemets doublés,
 * retours à la ligne dans les champs), fins de ligne LF ou CRLF, BOM UTF-8.
 *
 * Particularité PassBi AFTU/DDD : calendar_dates.txt a un en-tête
 * « service_id;date;exception_type » (point-virgule) alors que les lignes de
 * données sont séparées par des virgules. Le séparateur est donc détecté
 * séparément pour l'en-tête et pour le corps (première ligne de données).
 *
 * Les lignes sont des tableaux de chaînes (pas d'objets) et peuvent être
 * consommées en flux (`onRow`) pour les grandes tables (stop_times : 677 918
 * lignes pour PassBi AFTU) sans matérialiser le tableau complet.
 */

function detectDelimiter(line) {
  let commas = 0; let semis = 0; let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const c = line.charCodeAt(i);
    if (c === 34) inQuotes = !inQuotes;
    else if (!inQuotes) { if (c === 44) commas++; else if (c === 59) semis++; }
  }
  return semis > commas ? ';' : ',';
}

/** Découpe une seule ligne (sans saut de ligne) selon un séparateur. */
function splitLine(line, delimiter) {
  const out = [];
  const d = delimiter.charCodeAt(0);
  let field = '';
  let inQuotes = false;
  let start = 0;
  let simple = true; // aucun guillemet rencontré dans le champ courant
  for (let i = 0; i < line.length; i++) {
    const c = line.charCodeAt(i);
    if (inQuotes) {
      if (c === 34) {
        if (line.charCodeAt(i + 1) === 34) { field += '"'; i++; } else inQuotes = false;
      } else field += line[i];
      continue;
    }
    if (c === 34) { if (simple) { field = line.slice(start, i); simple = false; } inQuotes = true; continue; }
    if (c === d) { out.push(simple ? line.slice(start, i) : field); field = ''; start = i + 1; simple = true; }
    else if (!simple) field += line[i];
  }
  out.push(simple ? line.slice(start) : field);
  return out;
}

/**
 * @param {string} text contenu du fichier
 * @param {{onRow?: (row: string[], index: number) => void, onHeader?: (header: string[], columnIndex: (name: string) => number) => void}} [options]
 *   Avec `onRow`, les lignes ne sont pas conservées dans `rows` ; `onHeader`
 *   est appelé dès l'en-tête lu (avant la première ligne).
 * @returns {{header: string[], rows: string[][], delimiter: string, bodyDelimiter: string, rowCount: number, columnIndex: (name: string) => number}}
 */
function parseCsv(text, options = {}) {
  if (typeof text !== 'string') throw new TypeError('parseCsv attend une chaîne');
  const onRow = typeof options.onRow === 'function' ? options.onRow : null;
  let pos = 0;
  const n = text.length;
  if (n > 0 && text.charCodeAt(0) === 0xfeff) pos = 1;
  // En-tête (une ligne, guillemets rares).
  let eol = text.indexOf('\n', pos);
  if (eol === -1) eol = n;
  const headerLine = text.slice(pos, eol).replace(/\r$/, '');
  const delimiter = detectDelimiter(headerLine);
  const header = splitLine(headerLine, delimiter).map((h) => h.trim());
  const index = new Map(header.map((h, k) => [h, k]));
  const columnIndex = (name) => (index.has(name) ? index.get(name) : -1);
  if (typeof options.onHeader === 'function') options.onHeader(header, columnIndex);
  pos = eol + 1;
  // Séparateur du corps : première ligne non vide.
  let bodyDelimiter = delimiter;
  {
    let p = pos;
    while (p < n) {
      let e = text.indexOf('\n', p);
      if (e === -1) e = n;
      const line = text.slice(p, e).replace(/\r$/, '');
      if (line.length > 0) { bodyDelimiter = detectDelimiter(line); break; }
      p = e + 1;
    }
  }
  const d = bodyDelimiter.charCodeAt(0);
  const rows = [];
  let rowCount = 0;
  const emit = (row) => {
    if (row.length === 1 && row[0] === '') return;
    if (onRow) onRow(row, rowCount); else rows.push(row);
    rowCount++;
  };
  // Corps : chemin rapide sans guillemets, chemin complet sinon.
  while (pos < n) {
    let e = text.indexOf('\n', pos);
    if (e === -1) e = n;
    let line = text.slice(pos, e);
    pos = e + 1;
    if (line.charCodeAt(line.length - 1) === 13) line = line.slice(0, -1);
    if (line.indexOf('"') === -1) {
      if (line.length === 0) continue;
      const row = [];
      let start = 0;
      for (let i = 0; i < line.length; i++) {
        if (line.charCodeAt(i) === d) { row.push(line.slice(start, i)); start = i + 1; }
      }
      row.push(line.slice(start));
      emit(row);
      continue;
    }
    // Champ(s) entre guillemets : peut s'étendre sur plusieurs lignes.
    let quotes = countQuotes(line);
    while (quotes % 2 === 1 && pos < n) {
      let e2 = text.indexOf('\n', pos);
      if (e2 === -1) e2 = n;
      const next = text.slice(pos, e2);
      pos = e2 + 1;
      line += `\n${next.replace(/\r$/, '')}`;
      quotes += countQuotes(next);
    }
    emit(splitLine(line, bodyDelimiter));
  }
  return { header, rows, delimiter, bodyDelimiter, rowCount, columnIndex };
}

function countQuotes(s) {
  let q = 0;
  for (let i = 0; i < s.length; i++) if (s.charCodeAt(i) === 34) q++;
  return q;
}

/** Convertit un tableau de lignes en objets (petites tables uniquement). */
function rowsToObjects(table) {
  const { header, rows } = table;
  return rows.map((r) => {
    const o = {};
    for (let k = 0; k < header.length; k++) o[header[k]] = r[k] === undefined ? '' : r[k];
    return o;
  });
}

module.exports = { parseCsv, rowsToObjects, detectDelimiter, splitLine };
