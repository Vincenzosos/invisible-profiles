import { useMemo, useState } from 'react';
import centroidsData from '../data/centroids.json';
import questionsData from '../data/profiler_questions.json';
import { matchProfile } from '../lib/profiler';
import { downloadFile, readCSV, writeCSV } from '../lib/csv';
import { coerceValue, suggestMapping, type ColumnSuggestion, type MappingSource } from '../lib/csv-mapping';
import { VAR_LIST, VAR_SPECS } from '../lib/var-specs';
import ClusterDossier from './ClusterDossier';
import {
  autoBuckets,
  benchmarkShares,
  chiSquareVsBenchmark,
  cohortDistribution,
  confidenceBucket,
  formatPValue,
  percentile,
  pivotByGroup,
} from '../lib/cohort-stats';
import type { Country } from '../lib/profiler';

type Country2 = Country;

const QUESTION_PROMPTS: Record<string, string> = Object.fromEntries(
  (questionsData.questions as { var: string; prompt: string }[]).map((q) => [
    q.var,
    q.prompt,
  ]),
);

type ScoredRow = {
  inputRow: Record<string, string>;
  coerced: Record<string, number>;
  predicted_profile: string;
  best_distance: number;
  membership_top1_pct: number;
  membership_top2_profile: string;
  membership_top2_pct: number;
  zScores: Record<string, number>;
  twin_country_profile: string;
  twin_country_distance: number;
  confidence: 'confident' | 'borderline' | 'weak';
  distance_percentile: number; // filled after scoring all rows
  validation: { var: string; reason: string; detail: string }[];
};

type MissingStrategy = 'skip' | 'mean' | 'median';

type Props = {
  country: Country2;
  onBack: () => void;
};

const CONFIDENCE_COLORS: Record<ScoredRow['confidence'], string> = {
  confident: 'bg-emerald-100 text-emerald-800',
  borderline: 'bg-amber-100 text-amber-800',
  weak: 'bg-rose-100 text-rose-800',
};

const SOURCE_LABEL: Record<MappingSource, string> = {
  synonym: 'name match',
  fuzzy: 'fuzzy name',
  range: 'value range',
  manual: 'manual',
  none: '—',
};

// Examples of fields a typical company DB would carry that can act as
// a proxy for each profiler variable. Surfaced under the mapping row to
// help analysts understand "what of mine matches this".
const COMMERCIAL_PROXIES: Record<string, string> = {
  sphus:        'Customer-stated health, claim frequency, chronic-condition flag',
  eurod:        'Wellbeing or mental-health survey score, customer-effort score',
  iadl:         'Caregiver-flag, assistance-product subscriptions, frequent service contacts',
  fdistress:    'Late-payment count, debt-to-income, declined-card events, credit score',
  internet:     'App login frequency, web sessions, email opens (any digital touchpoint = 1)',
  sn_size_w9:   'Referrals issued, household size on policy, joint-account members',
  fluency:      'Rare in commercial DBs — leave unmapped if you do not have a verbal-fluency proxy',
  casp:         'NPS score, life-satisfaction survey, brand-affinity index',
  loneliness:   'Engagement frequency (low = candidate for lonelier), days-since-last-contact',
  hope_future:  'Renewal intention, churn-risk inverse, multi-year product subscription',
};

const SOURCE_TONE: Record<MappingSource, string> = {
  synonym: 'text-emerald-700',
  fuzzy: 'text-emerald-600',
  range: 'text-amber-700',
  manual: 'text-zinc-700',
  none: 'text-zinc-400',
};

export default function CsvUpload({ country, onBack }: Props) {
  const [parsed, setParsed] = useState<{
    headers: string[];
    rows: Record<string, string>[];
  } | null>(null);
  const [mapping, setMapping] = useState<Record<string, string>>({});
  const [suggestions, setSuggestions] = useState<Record<string, ColumnSuggestion>>({});
  const [filename, setFilename] = useState<string>('');
  const [error, setError] = useState<string | null>(null);
  const [scored, setScored] = useState<ScoredRow[] | null>(null);
  const [missingStrategy, setMissingStrategy] = useState<MissingStrategy>('skip');
  const [pivotColumn, setPivotColumn] = useState<string>('');
  const [showAllRows, setShowAllRows] = useState(false);
  const [selectedCluster, setSelectedCluster] = useState<string | null>(null);

  const mappedCount = VAR_LIST.filter((v) => mapping[v.var]).length;
  const MIN_MAPPED = 3;
  const canScore = parsed && mappedCount >= MIN_MAPPED && parsed.rows.length > 0;

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
        // Build columns→values for range-based detection
        const colVals: Record<string, string[]> = {};
        for (const h of out.headers) {
          colVals[h] = out.rows.map((r) => r[h]);
        }
        const sug = suggestMapping(out.headers, colVals);
        const initialMapping: Record<string, string> = {};
        for (const v of Object.keys(sug)) {
          if (sug[v].header) initialMapping[v] = sug[v].header as string;
        }
        setParsed(out);
        setSuggestions(sug);
        setMapping(initialMapping);
      } catch (e) {
        setError(`Could not parse: ${(e as Error).message}`);
      }
    };
    reader.onerror = () => setError('Could not read the file.');
    reader.readAsText(file);
  };

  const onScore = () => {
    if (!parsed) return;
    const accumulated: { var: string; values: number[] }[] = VAR_LIST.map((v) => ({
      var: v.var,
      values: [],
    }));
    // First pass: coerce each row's values, collect parse errors and ok values
    type Row = {
      inputRow: Record<string, string>;
      coerced: Record<string, number>;
      validation: { var: string; reason: string; detail: string }[];
    };
    const rows: Row[] = [];
    for (const inputRow of parsed.rows) {
      const coerced: Record<string, number> = {};
      const validation: { var: string; reason: string; detail: string }[] = [];
      // Iterate only over MAPPED variables. Unmapped variables stay
      // out of the answers Record entirely; matchProfile then computes
      // distance on the subspace of available dimensions.
      for (const v of VAR_LIST) {
        const col = mapping[v.var];
        if (!col) continue; // unmapped — not a validation issue
        const raw = inputRow[col];
        const c = coerceValue(raw, v);
        if (c.ok) {
          coerced[v.var] = c.value;
          accumulated.find((a) => a.var === v.var)?.values.push(c.value);
        } else {
          validation.push({ var: v.var, reason: c.reason, detail: c.detail });
        }
      }
      rows.push({ inputRow, coerced, validation });
    }
    // Compute imputation values from valid observations only
    const imputeMap = new Map<string, number>();
    for (const a of accumulated) {
      const sorted = [...a.values].sort((x, y) => x - y);
      if (sorted.length === 0) {
        imputeMap.set(a.var, (VAR_SPECS[a.var].min + VAR_SPECS[a.var].max) / 2);
      } else if (missingStrategy === 'mean') {
        imputeMap.set(a.var, sorted.reduce((s, x) => s + x, 0) / sorted.length);
      } else {
        // median (used also as fallback when strategy is "skip")
        const mid = Math.floor(sorted.length / 2);
        imputeMap.set(
          a.var,
          sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid],
        );
      }
    }
    // Second pass: build scored rows; honour missing-data strategy
    const scoredRows: Omit<ScoredRow, 'distance_percentile'>[] = [];
    for (const r of rows) {
      // If skip strategy AND we have validation issues on mapped vars,
      // skip this row. Unmapped vars never count as validation issues.
      if (missingStrategy === 'skip' && r.validation.length > 0) continue;
      const answers: Record<string, number> = { ...r.coerced };
      // Impute missing only for MAPPED vars where the row had a parsing
      // failure. Unmapped vars stay out of answers — matchProfile uses
      // subspace distance on the provided dimensions.
      for (const v of VAR_LIST) {
        if (!mapping[v.var]) continue; // skip unmapped
        if (!(v.var in answers)) {
          answers[v.var] = imputeMap.get(v.var) ?? 0;
        }
      }
      const result = matchProfile(country, answers, centroidsData);
      const top1 = result.membership[0];
      const top2 = result.membership[1];
      const conf = confidenceBucket(
        top1?.probability ?? 0,
        top2?.probability ?? 0,
      );
      // Track all input columns; also keep raw row + the SHARE-coded
      // values that fed the scoring (used by the cluster dossier to
      // compute cohort means within each cluster).
      scoredRows.push({
        inputRow: r.inputRow,
        coerced: answers,
        predicted_profile: result.best.name,
        best_distance: result.best.distance,
        membership_top1_pct: top1?.probability ?? 0,
        membership_top2_profile: top2?.name ?? '',
        membership_top2_pct: top2?.probability ?? 0,
        zScores: result.best.zScores,
        twin_country_profile: result.twinName ?? '',
        twin_country_distance: result.twinDistance ?? 0,
        confidence: conf,
        validation: r.validation,
      });
    }
    // Compute within-cohort distance percentile
    const dists = scoredRows.map((s) => s.best_distance);
    const final: ScoredRow[] = scoredRows.map((s) => ({
      ...s,
      distance_percentile: percentile(s.best_distance, dists),
    }));
    setScored(final);
    setShowAllRows(false);
  };

  const summary = useMemo(() => {
    if (!scored) return null;
    const benchmark = benchmarkShares(country);
    const predictions = scored.map((s) => s.predicted_profile);
    const dist = cohortDistribution(predictions, benchmark);
    const chi = chiSquareVsBenchmark(predictions, benchmark);
    const profiles = benchmark.map((b) => b.name);
    return { dist, chi, profiles };
  }, [scored, country]);

  // List of CSV columns NOT mapped to a profiler variable. Surfaced as
  // demographic context inside the cluster dossier.
  const unmappedColumns = useMemo(() => {
    if (!parsed) return [] as string[];
    const mapped = new Set(Object.values(mapping));
    return parsed.headers.filter((h) => !mapped.has(h));
  }, [parsed, mapping]);

  // Detect candidate pivot columns: anything that's not in the mapping,
  // is low-cardinality (≤ ~12 levels) when treated as string. Also
  // numeric columns become candidates via auto-buckets.
  const pivotCandidates = useMemo(() => {
    if (!parsed || !scored) return [] as { header: string; cardinality: number; numeric: boolean }[];
    const mapped = new Set(Object.values(mapping));
    const out: { header: string; cardinality: number; numeric: boolean }[] = [];
    for (const h of parsed.headers) {
      if (mapped.has(h)) continue;
      const vals = scored.map((s) => s.inputRow[h]).filter((v) => v !== undefined && v !== '');
      const unique = new Set(vals);
      const numericCount = vals.filter((v) => !Number.isNaN(Number(v))).length;
      const isNumeric = numericCount === vals.length && vals.length > 0;
      if (isNumeric || unique.size <= 12) {
        out.push({ header: h, cardinality: unique.size, numeric: isNumeric });
      }
    }
    return out;
  }, [parsed, scored, mapping]);

  const pivot = useMemo(() => {
    if (!scored || !summary || !pivotColumn) return null;
    const predictions = scored.map((s) => s.predicted_profile);
    let groupVals: (string | undefined)[];
    const cand = pivotCandidates.find((c) => c.header === pivotColumn);
    if (cand?.numeric) {
      const nums = scored.map((s) => Number(s.inputRow[pivotColumn]));
      groupVals = autoBuckets(nums, 4);
    } else {
      groupVals = scored.map((s) => s.inputRow[pivotColumn] || undefined);
    }
    return pivotByGroup(predictions, groupVals, summary.profiles);
  }, [scored, summary, pivotColumn, pivotCandidates]);

  const validationStats = useMemo(() => {
    if (!scored) return null;
    let issues = 0;
    for (const s of scored) issues += s.validation.length;
    const skipped = parsed ? parsed.rows.length - scored.length : 0;
    return { issues, skipped, total: parsed?.rows.length ?? 0 };
  }, [scored, parsed]);

  const onDownload = () => {
    if (!scored || !parsed) return;
    const zCols = VAR_LIST.map((v) => `z_${v.var}`);
    const augmentedHeaders = [
      ...parsed.headers,
      'predicted_profile',
      'best_distance',
      'distance_percentile',
      'confidence',
      'membership_top1_pct',
      'membership_top2_profile',
      'membership_top2_pct',
      'twin_country_profile',
      'twin_country_distance',
      ...zCols,
    ];
    const rows = scored.map((s) => {
      const row: Record<string, string> = { ...s.inputRow };
      row.predicted_profile = s.predicted_profile;
      row.best_distance = s.best_distance.toFixed(4);
      row.distance_percentile = s.distance_percentile.toFixed(1);
      row.confidence = s.confidence;
      row.membership_top1_pct = (s.membership_top1_pct * 100).toFixed(2);
      row.membership_top2_profile = s.membership_top2_profile;
      row.membership_top2_pct = (s.membership_top2_pct * 100).toFixed(2);
      row.twin_country_profile = s.twin_country_profile;
      row.twin_country_distance = s.twin_country_distance.toFixed(4);
      for (const v of VAR_LIST) {
        row[`z_${v.var}`] = (s.zScores[v.var] ?? 0).toFixed(3);
      }
      return row;
    });
    const csv = writeCSV(augmentedHeaders, rows);
    const base = filename.replace(/\.csv$/i, '') || 'profiled';
    downloadFile(`${base}_profiled.csv`, csv);
  };

  return (
    <section className="space-y-10 max-w-4xl">
      <header className="space-y-3">
        <p className="eyebrow">CSV batch · {country}</p>
        <h2 className="display-2 text-slate-900">Score a whole cohort.</h2>
        <p className="text-base text-zinc-700 leading-relaxed max-w-2xl">
          Upload a CSV with one row per individual. Columns are auto-mapped
          by name and value range. Strings like <code>Yes/No</code> or{' '}
          <code>Excellent/Poor</code> are coerced to SHARE coding. Each row
          gets a closest profile, a soft-membership distribution, full
          z-scores, and a cross-country twin. Cohort-level analytics test
          whether your sample differs from the SHARE benchmark.
        </p>
      </header>

      {!parsed && (
        <DropZone onFile={handleFile} />
      )}

      {error && (
        <p className="rounded-xl bg-rose-50 border border-rose-200 px-4 py-3 text-sm text-rose-800">
          {error}
        </p>
      )}

      {parsed && !scored && (
        <>
          <PreviewCard parsed={parsed} filename={filename} />
          <MappingCard
            parsed={parsed}
            mapping={mapping}
            suggestions={suggestions}
            onChange={(v, h) => {
              if (h === '') {
                setMapping((prev) => {
                  const { [v]: _drop, ...rest } = prev;
                  return rest;
                });
              } else {
                setMapping((prev) => ({ ...prev, [v]: h }));
              }
            }}
            missingStrategy={missingStrategy}
            onChangeMissing={setMissingStrategy}
            onScore={onScore}
            canScore={!!canScore}
            mappedCount={mappedCount}
            minMapped={MIN_MAPPED}
            onReset={() => {
              setParsed(null);
              setMapping({});
              setSuggestions({});
              setFilename('');
            }}
          />
        </>
      )}

      {scored && summary && validationStats && (
        <>
          <CohortAnalytics
            country={country}
            summary={summary}
            validation={validationStats}
            onDownload={onDownload}
            selectedCluster={selectedCluster}
            onSelectCluster={(name) =>
              setSelectedCluster((prev) => (prev === name ? null : name))
            }
          />

          {selectedCluster && (
            <ClusterDossier
              country={country}
              cluster={selectedCluster}
              rows={scored}
              unmappedColumns={unmappedColumns}
              onClose={() => setSelectedCluster(null)}
            />
          )}

          <PivotCard
            pivotCandidates={pivotCandidates}
            pivotColumn={pivotColumn}
            onPick={setPivotColumn}
            pivot={pivot}
            profiles={summary.profiles}
          />

          <RowsTable
            scored={scored}
            showAll={showAllRows}
            onToggle={() => setShowAllRows((v) => !v)}
          />

          <div className="flex items-center justify-between gap-3">
            <button
              type="button"
              onClick={() => {
                setScored(null);
                setParsed(null);
                setMapping({});
                setSuggestions({});
                setFilename('');
                setPivotColumn('');
                setSelectedCluster(null);
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

// ============================================================================
//  Sub-components — kept inline because they read the parent's local types
// ============================================================================

function DropZone({ onFile }: { onFile: (f: File) => void }) {
  const [dragActive, setDragActive] = useState(false);
  return (
    <div
      onDragOver={(e) => {
        e.preventDefault();
        setDragActive(true);
      }}
      onDragLeave={() => setDragActive(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragActive(false);
        const f = e.dataTransfer.files?.[0];
        if (f) onFile(f);
      }}
      className={[
        'rounded-2xl border-2 border-dashed p-12 text-center transition-colors',
        dragActive
          ? 'border-emerald-500 bg-emerald-50'
          : 'border-zinc-300 bg-white',
      ].join(' ')}
    >
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
            if (f) onFile(f);
          }}
        />
      </label>
      <p className="text-xs text-zinc-500 mt-6 max-w-md mx-auto leading-relaxed">
        Header row + one row per individual. Column names will be auto-mapped
        — no need to rename. Values can be numeric SHARE codes (1–5, 0/1, …)
        or natural-language labels (Yes/No, Excellent/Poor) which are
        coerced automatically.
      </p>
    </div>
  );
}

function PreviewCard({
  parsed,
  filename,
}: {
  parsed: { headers: string[]; rows: Record<string, string>[] };
  filename: string;
}) {
  return (
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
  );
}

function MappingCard({
  parsed,
  mapping,
  suggestions,
  onChange,
  missingStrategy,
  onChangeMissing,
  onScore,
  canScore,
  onReset,
  mappedCount,
  minMapped,
}: {
  parsed: { headers: string[]; rows: Record<string, string>[] };
  mapping: Record<string, string>;
  suggestions: Record<string, ColumnSuggestion>;
  onChange: (varName: string, header: string) => void;
  missingStrategy: MissingStrategy;
  onChangeMissing: (s: MissingStrategy) => void;
  onScore: () => void;
  canScore: boolean;
  onReset: () => void;
  mappedCount: number;
  minMapped: number;
}) {
  const total = VAR_LIST.length;
  const coveragePct = (mappedCount / total) * 100;
  const coverageTone =
    mappedCount >= 7
      ? 'text-emerald-700'
      : mappedCount >= 5
      ? 'text-amber-700'
      : 'text-rose-600';
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-5">
      <div>
        <p className="eyebrow">Map your columns</p>
        <p className="text-sm text-zinc-600 mt-2 max-w-2xl">
          Mappings auto-detected by name match, fuzzy similarity, or value
          range. Override any guess — confidence is shown beside each
          suggestion. A typical company DB rarely has all ten — leave
          unmapped what you don't have, scoring will use the subspace of
          available dimensions.
        </p>
      </div>

      <div className="rounded-xl bg-zinc-50 border border-zinc-200 p-4 space-y-2">
        <div className="flex items-baseline justify-between">
          <p className="text-sm font-medium text-slate-900">
            Data coverage:{' '}
            <span className={`tabular-nums ${coverageTone}`}>
              {mappedCount} of {total} variables mapped
            </span>
          </p>
          <span className="text-xs text-zinc-500">min {minMapped} required</span>
        </div>
        <div className="relative h-2 bg-white rounded-full overflow-hidden border border-zinc-200">
          <div
            className={[
              'absolute inset-y-0 left-0 rounded-full',
              mappedCount >= 7
                ? 'bg-emerald-600'
                : mappedCount >= 5
                ? 'bg-amber-500'
                : 'bg-rose-500',
            ].join(' ')}
            style={{ width: `${coveragePct.toFixed(1)}%` }}
          />
        </div>
        {mappedCount < 5 && mappedCount >= minMapped && (
          <p className="text-xs text-amber-700">
            Below 5 mapped variables: discrimination quality drops. Borderline
            and weak rows will dominate the output. Provide more variables
            for sharper assignment.
          </p>
        )}
        {mappedCount < minMapped && (
          <p className="text-xs text-rose-700">
            Map at least {minMapped} variables to enable scoring.
          </p>
        )}
      </div>
      <div className="space-y-3">
        {VAR_LIST.map((kv) => {
          const sug = suggestions[kv.var];
          const tone = sug ? SOURCE_TONE[sug.source] : SOURCE_TONE.none;
          const label = sug ? SOURCE_LABEL[sug.source] : '—';
          return (
            <div
              key={kv.var}
              className="grid grid-cols-1 sm:grid-cols-12 gap-3 items-start"
            >
              <div className="sm:col-span-5">
                <p className="text-sm font-medium text-slate-900">
                  <span className="font-mono text-xs text-emerald-700 mr-2">
                    {kv.var}
                  </span>
                  {QUESTION_PROMPTS[kv.var] ?? kv.var}
                </p>
                <p className="text-xs text-zinc-500 mt-0.5">
                  {kv.dim} · {kv.rangeHint}
                </p>
              </div>
              <div className="sm:col-span-7 space-y-1">
                <select
                  value={mapping[kv.var] ?? ''}
                  onChange={(e) => onChange(kv.var, e.target.value)}
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm bg-white"
                >
                  <option value="">— not mapped —</option>
                  {parsed.headers.map((h) => (
                    <option key={h} value={h}>
                      {h}
                    </option>
                  ))}
                </select>
                {sug && sug.header && (
                  <p className={`text-xs ${tone}`}>
                    Auto: <span className="font-medium">{label}</span>
                    {sug.source !== 'none' &&
                      sug.source !== 'manual' &&
                      ` · ${sug.reason}`}
                  </p>
                )}
                {COMMERCIAL_PROXIES[kv.var] && (
                  <p className="text-[11px] text-zinc-500 italic leading-relaxed">
                    Typical company-DB proxy: {COMMERCIAL_PROXIES[kv.var]}
                  </p>
                )}
              </div>
            </div>
          );
        })}
      </div>

      <div className="border-t border-zinc-200 pt-4 space-y-3">
        <p className="eyebrow">Missing or invalid values</p>
        <div className="flex flex-wrap gap-2">
          {(['skip', 'mean', 'median'] as const).map((s) => (
            <button
              key={s}
              type="button"
              onClick={() => onChangeMissing(s)}
              className={[
                'rounded-full px-4 py-1.5 text-xs border transition-colors',
                missingStrategy === s
                  ? 'bg-slate-900 text-white border-slate-900'
                  : 'bg-white text-zinc-700 border-zinc-300 hover:border-slate-500',
              ].join(' ')}
            >
              {s === 'skip' && 'Skip rows with issues'}
              {s === 'mean' && 'Impute with cohort mean'}
              {s === 'median' && 'Impute with cohort median'}
            </button>
          ))}
        </div>
        <p className="text-xs text-zinc-500">
          Skip is the most conservative. Imputation uses the cohort's own
          observed distribution per variable, computed only on parseable
          values.
        </p>
      </div>

      <div className="flex items-center justify-between pt-2">
        <button
          type="button"
          onClick={onReset}
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
  );
}

function CohortAnalytics({
  country,
  summary,
  validation,
  onDownload,
  selectedCluster,
  onSelectCluster,
}: {
  country: Country2;
  summary: ReturnType<typeof useCohortSummary>;
  validation: { issues: number; skipped: number; total: number };
  onDownload: () => void;
  selectedCluster: string | null;
  onSelectCluster: (name: string) => void;
}) {
  const { dist, chi } = summary;
  const top = [...dist].sort((a, b) => b.share - a.share)[0];
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-6">
      <div className="flex items-baseline justify-between gap-4 flex-wrap">
        <div>
          <p className="eyebrow">Cohort vs SHARE benchmark · {country}</p>
          <p className="display-3 text-slate-900 mt-2">
            {top && top.n > 0
              ? `${top.name} is the modal segment (${(top.share * 100).toFixed(1)}%).`
              : 'No predictions available.'}
          </p>
          <p className="text-sm text-zinc-600 mt-2">
            {chi.n.toLocaleString()} rows scored.{' '}
            {validation.skipped > 0 && (
              <>
                {validation.skipped.toLocaleString()} of{' '}
                {validation.total.toLocaleString()} skipped (validation issues).{' '}
              </>
            )}
            Pearson χ²({chi.df}) = {chi.chi2.toFixed(2)},{' '}
            <span className="font-medium">{formatPValue(chi.p)}</span>{' '}
            against the SHARE national distribution.
          </p>
          <p className="text-xs text-zinc-500 mt-2">
            Click any cluster name below to open its dossier.
          </p>
        </div>
        <button
          type="button"
          onClick={onDownload}
          className="rounded-xl bg-emerald-600 text-white px-5 py-2.5 hover:bg-emerald-700 transition-colors text-sm whitespace-nowrap"
        >
          Download scored CSV
        </button>
      </div>

      <div className="space-y-2.5">
        {dist.map((d) => {
          const cohortPct = d.share * 100;
          const benchPct = d.benchmarkShare * 100;
          const max = Math.max(cohortPct, benchPct, 1);
          const dPp = d.deltaPp;
          const dColor =
            Math.abs(dPp) < 2
              ? 'text-zinc-500'
              : dPp > 0
              ? 'text-emerald-700'
              : 'text-rose-600';
          const isSelected = selectedCluster === d.name;
          return (
            <button
              type="button"
              key={d.name}
              onClick={() => onSelectCluster(d.name)}
              className={[
                'w-full grid grid-cols-12 gap-3 items-center text-left rounded-lg px-2 py-1.5 transition-colors',
                isSelected
                  ? 'bg-emerald-50 ring-1 ring-emerald-300'
                  : 'hover:bg-zinc-50',
              ].join(' ')}
            >
              <div className="col-span-4 text-sm text-slate-900 truncate">
                {isSelected && (
                  <span className="text-emerald-700 mr-1">▸</span>
                )}
                {d.name}
              </div>
              <div className="col-span-6 space-y-1">
                <div className="relative h-2.5 bg-zinc-100 rounded-full overflow-hidden">
                  <div
                    className="absolute inset-y-0 left-0 bg-emerald-600 rounded-full"
                    style={{ width: `${(cohortPct / max) * 100}%` }}
                  />
                </div>
                <div className="relative h-2 bg-zinc-50 rounded-full overflow-hidden">
                  <div
                    className="absolute inset-y-0 left-0 bg-zinc-400 rounded-full"
                    style={{ width: `${(benchPct / max) * 100}%` }}
                  />
                </div>
              </div>
              <div className="col-span-2 text-right text-xs tabular-nums">
                <div className="text-slate-900 font-medium">
                  {cohortPct.toFixed(1)}%
                </div>
                <div className={`${dColor}`}>
                  {dPp >= 0 ? '+' : ''}
                  {dPp.toFixed(1)}pp
                </div>
              </div>
            </button>
          );
        })}
      </div>
      <p className="text-xs text-zinc-500">
        Top bar: your cohort. Bottom thin bar: SHARE Wave 9 national share. Δpp
        = cohort − benchmark in percentage points.
      </p>
    </article>
  );
}

// Aux type to type the prop in CohortAnalytics
type Summary = {
  dist: ReturnType<typeof cohortDistribution>;
  chi: ReturnType<typeof chiSquareVsBenchmark>;
  profiles: string[];
};
function useCohortSummary(): Summary {
  // Placeholder type-only function — never called. The summary is built
  // inline in the parent useMemo. Defined so the CohortAnalytics props
  // stay type-safe.
  return { dist: [], chi: { chi2: 0, df: 1, p: 1, n: 0 }, profiles: [] };
}
// Suppress "unused" warning while keeping the type linkage above.
void useCohortSummary;

function PivotCard({
  pivotCandidates,
  pivotColumn,
  onPick,
  pivot,
  profiles,
}: {
  pivotCandidates: { header: string; cardinality: number; numeric: boolean }[];
  pivotColumn: string;
  onPick: (h: string) => void;
  pivot: ReturnType<typeof pivotByGroup> | null;
  profiles: string[];
}) {
  if (pivotCandidates.length === 0) return null;
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-4">
      <div>
        <p className="eyebrow">Subgroup pivot</p>
        <p className="text-sm text-zinc-600 mt-2 max-w-2xl">
          Split the cohort distribution by an unmapped column from your CSV.
          Numeric columns are auto-bucketed into quartiles.
        </p>
      </div>
      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => onPick('')}
          className={[
            'rounded-full px-3 py-1.5 text-xs border',
            pivotColumn === ''
              ? 'bg-slate-900 text-white border-slate-900'
              : 'bg-white text-zinc-700 border-zinc-300 hover:border-slate-500',
          ].join(' ')}
        >
          (no split)
        </button>
        {pivotCandidates.map((c) => (
          <button
            key={c.header}
            type="button"
            onClick={() => onPick(c.header)}
            className={[
              'rounded-full px-3 py-1.5 text-xs border',
              pivotColumn === c.header
                ? 'bg-slate-900 text-white border-slate-900'
                : 'bg-white text-zinc-700 border-zinc-300 hover:border-slate-500',
            ].join(' ')}
          >
            {c.header}
            <span className="text-zinc-400 ml-1">
              ({c.numeric ? 'numeric' : `${c.cardinality} levels`})
            </span>
          </button>
        ))}
      </div>
      {pivot && pivot.levels.length > 0 && (
        <div className="overflow-x-auto">
          <table className="text-xs min-w-full">
            <thead>
              <tr className="border-b border-zinc-200">
                <th className="text-left font-medium text-zinc-600 py-2 pr-3">
                  Profile
                </th>
                {pivot.levels.map((l, ci) => (
                  <th
                    key={l}
                    className="text-right font-medium text-zinc-600 py-2 px-3 whitespace-nowrap"
                  >
                    {l}
                    <div className="text-[10px] text-zinc-400 font-normal">
                      n = {pivot.counts[ci]}
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {profiles.map((p, ri) => (
                <tr key={p} className="border-b border-zinc-100 last:border-0">
                  <td className="py-1.5 pr-3 text-slate-900">{p}</td>
                  {pivot.levels.map((_l, ci) => {
                    const v = pivot.matrix[ri][ci];
                    const intensity = Math.min(1, v * 1.5);
                    return (
                      <td
                        key={ci}
                        className="text-right tabular-nums px-3 py-1.5"
                        style={{
                          backgroundColor: `rgba(5, 150, 105, ${intensity * 0.15})`,
                        }}
                      >
                        {(v * 100).toFixed(0)}%
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </article>
  );
}

function RowsTable({
  scored,
  showAll,
  onToggle,
}: {
  scored: ScoredRow[];
  showAll: boolean;
  onToggle: () => void;
}) {
  const visible = showAll ? scored : scored.slice(0, 10);
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-3">
      <div className="flex items-baseline justify-between">
        <p className="eyebrow">Per-row prediction</p>
        {scored.length > 10 && (
          <button
            type="button"
            onClick={onToggle}
            className="text-xs text-emerald-700 hover:text-emerald-900"
          >
            {showAll ? 'Show first 10' : `Show all ${scored.length.toLocaleString()}`}
          </button>
        )}
      </div>
      <div className="overflow-x-auto">
        <table className="text-xs min-w-full">
          <thead>
            <tr className="text-left text-zinc-600 border-b border-zinc-200">
              <th className="px-2 py-1.5 font-medium">#</th>
              <th className="px-2 py-1.5 font-medium">Profile</th>
              <th className="px-2 py-1.5 font-medium">Conf.</th>
              <th className="px-2 py-1.5 font-medium text-right">Top-1</th>
              <th className="px-2 py-1.5 font-medium">Runner-up</th>
              <th className="px-2 py-1.5 font-medium text-right">Top-2</th>
              <th className="px-2 py-1.5 font-medium text-right">Dist.</th>
              <th className="px-2 py-1.5 font-medium text-right">Pctile</th>
              <th className="px-2 py-1.5 font-medium">Cross-country twin</th>
            </tr>
          </thead>
          <tbody>
            {visible.map((s, i) => (
              <tr key={i} className="border-b border-zinc-100 last:border-0">
                <td className="px-2 py-1.5 tabular-nums text-zinc-500">{i + 1}</td>
                <td className="px-2 py-1.5 font-medium text-slate-900">
                  {s.predicted_profile}
                </td>
                <td className="px-2 py-1.5">
                  <span
                    className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${CONFIDENCE_COLORS[s.confidence]}`}
                  >
                    {s.confidence}
                  </span>
                </td>
                <td className="px-2 py-1.5 text-right tabular-nums">
                  {(s.membership_top1_pct * 100).toFixed(1)}%
                </td>
                <td className="px-2 py-1.5 text-zinc-700">
                  {s.membership_top2_profile}
                </td>
                <td className="px-2 py-1.5 text-right tabular-nums text-zinc-600">
                  {(s.membership_top2_pct * 100).toFixed(1)}%
                </td>
                <td className="px-2 py-1.5 text-right tabular-nums text-zinc-600">
                  {s.best_distance.toFixed(2)}
                </td>
                <td className="px-2 py-1.5 text-right tabular-nums text-zinc-500">
                  {s.distance_percentile.toFixed(0)}
                </td>
                <td className="px-2 py-1.5 text-zinc-700">
                  {s.twin_country_profile}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-zinc-500">
        <span className="font-medium">Conf.</span> = confidence bucket from the
        top-1/top-2 split. <span className="font-medium">Pctile</span> =
        within-cohort percentile of the row's distance to its centroid (high
        = atypical). Download to get full z-scores per row.
      </p>
    </article>
  );
}
