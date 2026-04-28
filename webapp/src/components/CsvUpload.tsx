import { useMemo, useState } from 'react';
import centroidsData from '../data/centroids.json';
import questionsData from '../data/profiler_questions.json';
import { matchProfile } from '../lib/profiler';
import { downloadFile, readCSV, writeCSV } from '../lib/csv';
import type { Country } from '../lib/profiler';

// 10-variable subset the engine needs (same as the manual quiz).
type KeyVar = { var: string; dim: string; label: string };

const KEY_VARS: KeyVar[] = centroidsData.key_variables.map((kv) => ({
  var: kv.var,
  dim: kv.dim,
  label: kv.label,
}));

const QUESTION_PROMPTS: Record<string, string> = Object.fromEntries(
  (questionsData.questions as { var: string; prompt: string }[]).map((q) => [
    q.var,
    q.prompt,
  ]),
);

type ScoredRow = {
  inputRow: Record<string, string>;
  predicted_profile: string;
  best_distance: number;
  membership_top1_pct: number;
  membership_top2_profile: string;
  membership_top2_pct: number;
};

type Props = {
  country: Country;
  onBack: () => void;
};

// A column-name matches a SHARE variable when the trimmed lower-case
// header equals the variable, contains it as a token, or matches a
// short list of common synonyms. This keeps auto-mapping useful for
// the realistic case where a researcher named the column slightly
// differently (e.g. "Internet_use_7d").
const SYNONYMS: Record<string, string[]> = {
  sphus: ['sphus', 'self_rated_health', 'self-rated-health', 'health_rating'],
  eurod: ['eurod', 'eurod_score', 'depression', 'depression_score'],
  iadl: ['iadl', 'iadl_score', 'iadl_count', 'adl_instr'],
  fdistress: ['fdistress', 'financial_distress', 'ends_meet', 'co007_'],
  internet: ['internet', 'internet_use', 'internet_7d', 'it005_'],
  sn_size_w9: ['sn_size_w9', 'sn_size', 'social_network', 'network_size'],
  fluency: ['fluency', 'animals_60s', 'verbal_fluency', 'cf016tot'],
  casp: ['casp', 'casp12', 'casp_12', 'quality_of_life'],
  loneliness: ['loneliness', 'ucla_loneliness', 'lone_score'],
  hope_future: ['hope_future', 'hope', 'hopes_future', 'mh032_'],
};

function autoMap(headers: string[]): Record<string, string> {
  const norm = (s: string) =>
    s.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
  const normalized = headers.map((h) => ({ raw: h, norm: norm(h) }));
  const out: Record<string, string> = {};
  for (const v of KEY_VARS) {
    const wantList = SYNONYMS[v.var] ?? [v.var];
    let hit = normalized.find((h) => wantList.includes(h.norm));
    if (!hit) {
      // partial match fallback: header contains the var name as a token
      hit = normalized.find((h) =>
        wantList.some((w) => h.norm.includes(w) || w.includes(h.norm)),
      );
    }
    if (hit) out[v.var] = hit.raw;
  }
  return out;
}

export default function CsvUpload({ country, onBack }: Props) {
  const [parsed, setParsed] = useState<{
    headers: string[];
    rows: Record<string, string>[];
  } | null>(null);
  const [mapping, setMapping] = useState<Record<string, string>>({});
  const [filename, setFilename] = useState<string>('');
  const [error, setError] = useState<string | null>(null);
  const [scored, setScored] = useState<ScoredRow[] | null>(null);

  const allMapped = KEY_VARS.every((v) => mapping[v.var]);
  const canScore = parsed && allMapped && parsed.rows.length > 0;

  const handleFile = (file: File) => {
    setError(null);
    setScored(null);
    setFilename(file.name);
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const text = String(reader.result ?? '');
        const out = readCSV(text);
        if (out.headers.length === 0 || out.rows.length === 0) {
          setError('The file appears empty or unreadable as CSV.');
          setParsed(null);
          return;
        }
        setParsed(out);
        setMapping(autoMap(out.headers));
      } catch (e) {
        setError(`Could not parse: ${(e as Error).message}`);
      }
    };
    reader.onerror = () => setError('Could not read the file.');
    reader.readAsText(file);
  };

  const onScore = () => {
    if (!parsed) return;
    const out: ScoredRow[] = [];
    for (const row of parsed.rows) {
      const answers: Record<string, number> = {};
      for (const kv of KEY_VARS) {
        const col = mapping[kv.var];
        const raw = row[col];
        const num = Number(raw);
        if (!Number.isNaN(num) && raw !== '' && raw !== undefined) {
          answers[kv.var] = num;
        }
      }
      const result = matchProfile(country, answers, centroidsData);
      const top1 = result.membership[0];
      const top2 = result.membership[1];
      out.push({
        inputRow: row,
        predicted_profile: result.best.name,
        best_distance: result.best.distance,
        membership_top1_pct: top1 ? top1.probability : 0,
        membership_top2_profile: top2 ? top2.name : '',
        membership_top2_pct: top2 ? top2.probability : 0,
      });
    }
    setScored(out);
  };

  const summary = useMemo(() => {
    if (!scored) return null;
    const counts = new Map<string, number>();
    for (const s of scored) {
      counts.set(s.predicted_profile, (counts.get(s.predicted_profile) ?? 0) + 1);
    }
    const total = scored.length;
    return Array.from(counts.entries())
      .map(([name, n]) => ({ name, n, pct: n / total }))
      .sort((a, b) => b.n - a.n);
  }, [scored]);

  const onDownload = () => {
    if (!scored || !parsed) return;
    const augmentedHeaders = [
      ...parsed.headers,
      'predicted_profile',
      'best_distance',
      'membership_top1_pct',
      'membership_top2_profile',
      'membership_top2_pct',
    ];
    const rows = scored.map((s) => ({
      ...s.inputRow,
      predicted_profile: s.predicted_profile,
      best_distance: s.best_distance.toFixed(4),
      membership_top1_pct: (s.membership_top1_pct * 100).toFixed(2),
      membership_top2_profile: s.membership_top2_profile,
      membership_top2_pct: (s.membership_top2_pct * 100).toFixed(2),
    }));
    const csv = writeCSV(augmentedHeaders, rows);
    const base = filename.replace(/\.csv$/i, '') || 'profiled';
    downloadFile(`${base}_profiled.csv`, csv);
  };

  return (
    <section className="space-y-10 max-w-3xl">
      <header className="space-y-3">
        <p className="eyebrow">CSV batch · {country}</p>
        <h2 className="display-2 text-slate-900">Score a whole cohort.</h2>
        <p className="text-base text-zinc-700 leading-relaxed max-w-2xl">
          Upload a CSV with one row per individual. Map your columns to the
          ten profiler variables — even if your column names don't match
          exactly. Each row gets a closest profile and a soft-membership
          distribution. Nothing leaves the browser.
        </p>
      </header>

      {!parsed && (
        <div className="rounded-2xl border-2 border-dashed border-zinc-300 bg-white p-12 text-center">
          <p className="text-base text-zinc-700">
            Drop a <code className="font-mono">.csv</code> file here, or
          </p>
          <label className="inline-block mt-4 cursor-pointer rounded-xl bg-slate-900 text-white px-5 py-2.5 hover:bg-slate-700 transition-colors">
            Choose file
            <input
              type="file"
              accept=".csv,text/csv"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) handleFile(f);
              }}
            />
          </label>
          <p className="text-xs text-zinc-500 mt-6 max-w-md mx-auto leading-relaxed">
            Expected: header row + one row per individual. Columns can be
            named anything — you'll map them to profiler variables in the
            next step. Values must be numeric on the SHARE coding (e.g.
            sphus 1–5, internet 0/1).
          </p>
        </div>
      )}

      {error && (
        <p className="rounded-xl bg-rose-50 border border-rose-200 px-4 py-3 text-sm text-rose-800">
          {error}
        </p>
      )}

      {parsed && !scored && (
        <>
          <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-4">
            <p className="eyebrow">Preview · {filename}</p>
            <p className="text-sm text-zinc-700">
              {parsed.rows.length.toLocaleString()} rows · {parsed.headers.length}{' '}
              columns
            </p>
            <div className="overflow-x-auto">
              <table className="text-xs min-w-full">
                <thead>
                  <tr>
                    {parsed.headers.slice(0, 8).map((h) => (
                      <th
                        key={h}
                        className="text-left font-medium text-zinc-600 px-2 py-1.5 whitespace-nowrap"
                      >
                        {h}
                      </th>
                    ))}
                    {parsed.headers.length > 8 && (
                      <th className="text-zinc-400 px-2">
                        +{parsed.headers.length - 8} more
                      </th>
                    )}
                  </tr>
                </thead>
                <tbody>
                  {parsed.rows.slice(0, 3).map((r, i) => (
                    <tr key={i} className="border-t border-zinc-100">
                      {parsed.headers.slice(0, 8).map((h) => (
                        <td
                          key={h}
                          className="px-2 py-1.5 text-zinc-700 whitespace-nowrap tabular-nums"
                        >
                          {r[h]}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </article>

          <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-5">
            <div>
              <p className="eyebrow">Map your columns</p>
              <p className="text-sm text-zinc-600 mt-2 max-w-2xl">
                For each profiler variable, pick which column in your CSV
                contains the value. We auto-detect by name where we can.
              </p>
            </div>
            <div className="space-y-3">
              {KEY_VARS.map((kv) => (
                <div
                  key={kv.var}
                  className="grid grid-cols-1 sm:grid-cols-12 gap-3 items-start"
                >
                  <div className="sm:col-span-5">
                    <p className="text-sm font-medium text-slate-900">
                      <span className="font-mono text-xs text-emerald-700 mr-2">
                        {kv.var}
                      </span>
                      {QUESTION_PROMPTS[kv.var] ?? kv.label}
                    </p>
                    <p className="text-xs text-zinc-500 mt-0.5">
                      {kv.dim} · {kv.label}
                    </p>
                  </div>
                  <div className="sm:col-span-7">
                    <select
                      value={mapping[kv.var] ?? ''}
                      onChange={(e) =>
                        setMapping((prev) => ({
                          ...prev,
                          [kv.var]: e.target.value,
                        }))
                      }
                      className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm bg-white"
                    >
                      <option value="">— not mapped —</option>
                      {parsed.headers.map((h) => (
                        <option key={h} value={h}>
                          {h}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              ))}
            </div>
            <div className="flex items-center justify-between pt-2">
              <button
                type="button"
                onClick={() => {
                  setParsed(null);
                  setMapping({});
                  setFilename('');
                }}
                className="text-sm text-zinc-600 hover:text-slate-900 transition-colors"
              >
                Use a different file
              </button>
              <button
                type="button"
                onClick={onScore}
                disabled={!canScore}
                className="rounded-xl bg-slate-900 text-white px-6 py-2.5 hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
              >
                Score {parsed.rows.length.toLocaleString()} rows
              </button>
            </div>
          </article>
        </>
      )}

      {scored && summary && (
        <>
          <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-5">
            <div className="flex items-baseline justify-between gap-4 flex-wrap">
              <div>
                <p className="eyebrow">Distribution · {scored.length.toLocaleString()} rows scored</p>
                <p className="display-3 text-slate-900 mt-2">
                  {summary[0].name} is the modal segment ({(summary[0].pct * 100).toFixed(1)}%).
                </p>
              </div>
              <button
                type="button"
                onClick={onDownload}
                className="rounded-xl bg-emerald-600 text-white px-5 py-2.5 hover:bg-emerald-700 transition-colors text-sm"
              >
                Download scored CSV
              </button>
            </div>
            <div className="space-y-2.5">
              {summary.map((s) => (
                <div key={s.name} className="grid grid-cols-12 gap-3 items-center">
                  <div className="col-span-5 text-sm text-slate-900 truncate">
                    {s.name}
                  </div>
                  <div className="col-span-5 relative h-3 bg-zinc-100 rounded-full overflow-hidden">
                    <div
                      className="absolute inset-y-0 left-0 bg-emerald-600 rounded-full"
                      style={{ width: `${(s.pct * 100).toFixed(1)}%` }}
                    />
                  </div>
                  <div className="col-span-2 text-right text-xs tabular-nums text-zinc-700">
                    {s.n.toLocaleString()} ({(s.pct * 100).toFixed(1)}%)
                  </div>
                </div>
              ))}
            </div>
          </article>

          <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-3">
            <p className="eyebrow">First 10 rows · per-row prediction</p>
            <div className="overflow-x-auto">
              <table className="text-xs min-w-full">
                <thead>
                  <tr className="text-left text-zinc-600">
                    <th className="px-2 py-1.5 font-medium">#</th>
                    <th className="px-2 py-1.5 font-medium">Predicted profile</th>
                    <th className="px-2 py-1.5 font-medium text-right">Top-1 %</th>
                    <th className="px-2 py-1.5 font-medium">Runner-up</th>
                    <th className="px-2 py-1.5 font-medium text-right">Top-2 %</th>
                    <th className="px-2 py-1.5 font-medium text-right">Distance</th>
                  </tr>
                </thead>
                <tbody>
                  {scored.slice(0, 10).map((s, i) => (
                    <tr key={i} className="border-t border-zinc-100">
                      <td className="px-2 py-1.5 tabular-nums text-zinc-500">{i + 1}</td>
                      <td className="px-2 py-1.5 font-medium text-slate-900">{s.predicted_profile}</td>
                      <td className="px-2 py-1.5 text-right tabular-nums">{(s.membership_top1_pct * 100).toFixed(1)}%</td>
                      <td className="px-2 py-1.5 text-zinc-700">{s.membership_top2_profile}</td>
                      <td className="px-2 py-1.5 text-right tabular-nums text-zinc-600">{(s.membership_top2_pct * 100).toFixed(1)}%</td>
                      <td className="px-2 py-1.5 text-right tabular-nums text-zinc-600">{s.best_distance.toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {scored.length > 10 && (
              <p className="text-xs text-zinc-500">
                Showing 10 of {scored.length.toLocaleString()}. Download the
                CSV for the full result.
              </p>
            )}
          </article>

          <div className="flex items-center justify-between gap-3">
            <button
              type="button"
              onClick={() => {
                setScored(null);
                setParsed(null);
                setMapping({});
                setFilename('');
              }}
              className="rounded-xl border border-zinc-300 px-5 py-2.5 text-zinc-700 hover:bg-white hover:text-slate-900 transition-colors text-sm"
            >
              Score another file
            </button>
            <button
              type="button"
              onClick={onBack}
              className="text-sm text-zinc-600 hover:text-slate-900 transition-colors"
            >
              Back to choose mode
            </button>
          </div>
        </>
      )}

      {!scored && (
        <div className="flex justify-start">
          <button
            type="button"
            onClick={onBack}
            className="text-sm text-zinc-600 hover:text-slate-900 transition-colors"
          >
            ← Back to choose mode
          </button>
        </div>
      )}
    </section>
  );
}
