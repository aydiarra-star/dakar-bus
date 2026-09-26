// Lecteur CSV GTFS tolérant — miroir Dart de lib/external-gtfs/gtfs-csv.js.
// Délimiteur détecté séparément pour l'en-tête et le corps (les feeds PassBi
// AFTU/DDD ont un en-tête calendar_dates séparé par « ; » et des lignes « , »).

class CsvTable {
  CsvTable(this.header, this.rows, this.delimiter, this.bodyDelimiter);

  final List<String> header;
  final List<List<String>> rows;
  final String delimiter;
  final String bodyDelimiter;

  int get rowCount => rows.length;

  /// Index d'une colonne (-1 si absente).
  int columnIndex(String name) => header.indexOf(name);
}

String _detectDelimiter(String line) {
  int best = -1;
  String delimiter = ',';
  for (final String d in <String>[',', ';', '\t']) {
    final int n = _countOutsideQuotes(line, d);
    if (n > best) {
      best = n;
      delimiter = d;
    }
  }
  return delimiter;
}

int _countOutsideQuotes(String line, String d) {
  int n = 0;
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final String c = line[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes && c == d) {
      n++;
    }
  }
  return n;
}

/// Découpe une ligne CSV (guillemets RFC 4180, guillemets doublés).
List<String> splitCsvLine(String line, String delimiter) {
  final List<String> out = <String>[];
  final StringBuffer cur = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final String c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cur.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delimiter) {
      out.add(cur.toString().trim());
      cur.clear();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString().trim());
  return out;
}

int _countQuotes(String s) {
  int n = 0;
  for (int i = 0; i < s.length; i++) {
    if (s[i] == '"') n++;
  }
  return n;
}

/// Parse un texte GTFS (BOM retiré, CRLF accepté, lignes vides ignorées,
/// champs multi-lignes entre guillemets recollés).
CsvTable parseCsv(String text) {
  String src = text;
  if (src.isNotEmpty && src.codeUnitAt(0) == 0xFEFF) src = src.substring(1);
  final List<String> lines = src.split('\n');
  List<String>? header;
  String delimiter = ',';
  String? bodyDelimiter;
  final List<List<String>> rows = <List<String>>[];
  String pending = '';
  for (final String rawLine in lines) {
    String line = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;
    if (pending.isNotEmpty) {
      line = '$pending\n$line';
      pending = '';
    }
    if (line.trim().isEmpty) continue;
    if (_countQuotes(line).isOdd) {
      pending = line;
      continue;
    }
    if (header == null) {
      delimiter = _detectDelimiter(line);
      header = splitCsvLine(line, delimiter);
      continue;
    }
    bodyDelimiter ??= _detectDelimiter(line);
    final List<String> fields = splitCsvLine(line, bodyDelimiter);
    while (fields.length < header.length) {
      fields.add('');
    }
    rows.add(fields);
  }
  return CsvTable(header ?? <String>[], rows, delimiter, bodyDelimiter ?? delimiter);
}

/// Lignes sous forme de dictionnaires (colonne → valeur).
List<Map<String, String>> rowsToObjects(CsvTable table) {
  return table.rows.map((List<String> r) {
    final Map<String, String> o = <String, String>{};
    for (int i = 0; i < table.header.length; i++) {
      o[table.header[i]] = i < r.length ? r[i] : '';
    }
    return o;
  }).toList();
}
