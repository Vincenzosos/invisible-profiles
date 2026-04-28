// Minimal CSV utilities for the Profiler batch-scoring feature.
// Handles RFC-4180-style quoting (double-quote escapes), CRLF/LF
// line endings, and optional UTF-8 BOM. Designed for the kind of CSV
// an analyst would export from R, Stata, or Excel — not exotic formats.

export function parseCSV(text: string): string[][] {
  // Strip optional UTF-8 BOM
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);

  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let inQuotes = false;
  let i = 0;
  const n = text.length;

  while (i < n) {
    const c = text[i];

    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          // escaped quote
          cell += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      cell += c;
      i++;
      continue;
    }

    if (c === '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (c === ',') {
      row.push(cell);
      cell = '';
      i++;
      continue;
    }
    if (c === '\r') {
      i++;
      continue;
    }
    if (c === '\n') {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
      i++;
      continue;
    }
    cell += c;
    i++;
  }
  // flush trailing cell/row if file did not end with newline
  if (cell !== '' || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  // drop fully empty rows
  return rows.filter((r) => r.some((v) => v !== ''));
}

// Auto-detect header row + body + return parsed numeric+string maps.
export type CsvParsed = {
  headers: string[];
  rows: Record<string, string>[];
};

export function readCSV(text: string): CsvParsed {
  const cells = parseCSV(text);
  if (cells.length === 0) return { headers: [], rows: [] };
  const headers = cells[0].map((h) => h.trim());
  const rows = cells.slice(1).map((r) => {
    const obj: Record<string, string> = {};
    headers.forEach((h, i) => {
      obj[h] = (r[i] ?? '').trim();
    });
    return obj;
  });
  return { headers, rows };
}

// Serialise an array of records back to CSV. Quotes any value that
// contains a comma, double-quote, or newline.
export function writeCSV(headers: string[], rows: Record<string, unknown>[]): string {
  const escape = (v: unknown): string => {
    const s = v === null || v === undefined ? '' : String(v);
    if (/[",\r\n]/.test(s)) {
      return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
  };
  const lines: string[] = [];
  lines.push(headers.map(escape).join(','));
  for (const r of rows) {
    lines.push(headers.map((h) => escape(r[h])).join(','));
  }
  return lines.join('\n');
}

// Trigger a browser download of `content` as a file.
export function downloadFile(filename: string, content: string, mime = 'text/csv;charset=utf-8') {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => {
    URL.revokeObjectURL(url);
    a.remove();
  }, 100);
}
