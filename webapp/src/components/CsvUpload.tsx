import { useMemo, useState } from 'react';
import centroidsData from '../data/centroids.json';
import questionsData from '../data/profiler_questions.json';
import sampleCohortCsv from '../data/test_cohort.csv?raw';
import { matchProfile } from '../lib/profiler';
import { matchProfileWithImputation } from '../lib/imputation';
import { computeEvidence, type Evidence } from '../lib/evidence';
import { ksTwoSample } from '../lib/ks_test';
import { getQuantiles, isPlaceholder } from '../lib/marginals';
import { downloadFile, readCSV, writeCSV } from '../lib/csv';
import {
  applyRescaling,
  coerceValue,
  precomputeECDF,
  suggestMapping,
  type ColumnSuggestion,
  type MappingSource,
  type RescalingRule,
} from '../lib/csv-mapping';
import { VAR_LIST, VAR_SPECS } from '../lib/var-specs';
import CohortDashboard from './CohortDashboard';
import {
  autoBuckets,
  benchmarkShares,
  chiSquareVsBenchmark,
  cohortDistribution,
  confidenceBucket,
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
  coverage: { observed: number; total: number };
  imputation_top1_cluster: string;
  imputation_top1_share: number;
  imputation_top2_cluster: string;
  imputation_top2_share: number;
  imputation_distribution: { name: string; probability: number; meanDistance: number }[];
  evidence: Evidence;
};

type MissingStrategy = 'skip' | 'mean' | 'median';

type Props = {
  country: Country2;
  onBack: () => void;
};

const EVIDENCE_COLORS: Record<Evidence, string> = {
  strong: 'bg-blue-50 text-blue-800 border border-blue-200',
  moderate: 'bg-amber-50 text-amber-800 border border-amber-200',
  weak: 'bg-rose-50 text-rose-700 border border-rose-200',
};

const SOURCE_LABEL: Record<MappingSource, string> = {
  synonym: 'name match',
  fuzzy: 'fuzzy name',
  range: 'value range',
  manual: 'manual',
  rank_quantile: 'rank-quantile',
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
  synonym: 'text-blue-700',
  fuzzy: 'text-blue-600',
  range: 'text-amber-700',
  manual: 'text-zinc-700',
  rank_quantile: 'text-teal-700',
  none: 'text-zinc-400',
};

// ---- Pre-flight (Sprint 4) ------------------------------------------------

type PreflightSeverity = 'pass' | 'warn' | 'strong';

type PreflightEntry =
  | { var: string; kind: 'ks'; D: number; p: number; severity: PreflightSeverity }
  | {
      var: string;
      kind: 'binary';
      cohortRate: number;
      shareRate: number;
      absDiff: number;
      severity: PreflightSeverity;
    }
  | { var: string; kind: 'insufficient'; reason: string };

type Preflight =
  | { state: 'placeholder' }
  | { state: 'ready'; entries: PreflightEntry[]; tested: number; anyWarn: boolean };

export default function CsvUpload({ country, onBack }: Props) {
  const [parsed, setParsed] = useState<{
    headers: string[];
    rows: Record<string, string>[];
  } | null>(null);
  const [mapping, setMapping] = useState<Record<string, string>>({});
  const [suggestions, setSuggestions] = useState<Record<string, ColumnSuggestion>>({});
  const [rescaling, setRescaling] = useState<Record<string, RescalingRule>>({});
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

  // Pre-flight distributional check (Sprint 4): for each mapped non-binary
  // variable run a two-sample KS against the SHARE reference marginal; for
  // binary variables compare proportions. Disabled when the marginals
  // file is still the placeholder.
  const preflight = useMemo<Preflight>(() => {
    if (!parsed) return { state: 'ready', entries: [], tested: 0, anyWarn: false };
    if (isPlaceholder()) return { state: 'placeholder' };
    const entries: PreflightEntry[] = [];
    let tested = 0;
    for (const spec of VAR_LIST) {
      const col = mapping[spec.var];
      if (!col) continue;
      const rule = rescaling[spec.var];
      const values: number[] = [];
      for (const row of parsed.rows) {
        const raw = row[col] ?? '';
        let v: number | null = null;
        if (rule) {
          v = applyRescaling(raw, rule, spec);
        } else {
          const c = coerceValue(raw, spec);
          if (c.ok) v = c.value;
        }
        if (v !== null && !Number.isNaN(v)) values.push(v);
      }
      if (values.length < 5) {
        entries.push({
          var: spec.var,
          kind: 'insufficient',
          reason: 'fewer than 5 parseable values',
        });
        continue;
      }
      const ref = getQuantiles(country, spec.var);
      if (!ref || ref.length === 0) {
        entries.push({
          var: spec.var,
          kind: 'insufficient',
          reason: 'reference marginal missing',
        });
        continue;
      }
      if (spec.isBinary) {
        const cohortRate = values.reduce((s, x) => s + x, 0) / values.length;
        const shareRate = ref.reduce((s, x) => s + x, 0) / ref.length;
        const absDiff = Math.abs(cohortRate - shareRate);
        const severity: PreflightSeverity =
          absDiff < 0.1 ? 'pass' : absDiff < 0.25 ? 'warn' : 'strong';
        entries.push({
          var: spec.var,
          kind: 'binary',
          cohortRate,
          shareRate,
          absDiff,
          severity,
        });
        tested++;
      } else {
        // ref is pre-sorted (quantiles are ascending by construction).
        const ks = ksTwoSample(values, ref);
        const severity: PreflightSeverity =
          ks.p >= 0.05 ? 'pass' : ks.p >= 0.001 ? 'warn' : 'strong';
        entries.push({
          var: spec.var,
          kind: 'ks',
          D: ks.D,
          p: ks.p,
          severity,
        });
        tested++;
      }
    }
    const anyWarn = entries.some(
      (e) => e.kind !== 'insufficient' && (e.severity === 'warn' || e.severity === 'strong'),
    );
    return { state: 'ready', entries, tested, anyWarn };
  }, [parsed, mapping, rescaling, country]);

  // Shared parser used by both the file-upload path and the
  // "Try with sample data" path. Takes the CSV as a string.
  const ingestCsvText = (text: string, sourceFilename: string) => {
    setError(null);
    setScored(null);
    setFilename(sourceFilename);
    try {
      const out = readCSV(text);
      if (out.headers.length === 0 || out.rows.length === 0) {
        setError('The file appears empty or unreadable as CSV.');
        setParsed(null);
        return;
      }
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
      setRescaling({});
    } catch (e) {
      setError(`Could not parse: ${(e as Error).message}`);
    }
  };

  const handleFile = (file: File) => {
    const reader = new FileReader();
    reader.onload = () => ingestCsvText(String(reader.result ?? ''), file.name);
    reader.onerror = () => setError('Could not read the file.');
    reader.readAsText(file);
  };

  const handleLoadSample = () => {
    ingestCsvText(sampleCohortCsv, 'test_cohort.csv (sample)');
  };

  const handlePrintReport = () => {
    // Browser-native "Save as PDF" via the print dialog. Print stylesheet
    // (in index.css) suppresses navigation/footer for a clean handout.
    window.print();
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
        const rule = rescaling[v.var];
        if (rule) {
          const mapped = applyRescaling(raw ?? '', rule, v);
          if (mapped !== null) {
            coerced[v.var] = mapped;
            accumulated.find((a) => a.var === v.var)?.values.push(mapped);
          } else {
            validation.push({
              var: v.var,
              reason: 'empty',
              detail: 'missing in column',
            });
          }
          continue;
        }
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
      // Count mapped vars that have a numeric value. Full coverage =>
      // deterministic matchProfile path. Partial coverage => conditional
      // Gaussian imputation over the missing dimensions.
      const observedCount = VAR_LIST.reduce(
        (acc, v) => acc + (v.var in answers ? 1 : 0),
        0,
      );
      const useImputation = observedCount < VAR_LIST.length;
      const result = useImputation
        ? matchProfileWithImputation(country, answers, centroidsData)
        : matchProfile(country, answers, centroidsData);
      const top1 = result.membership[0];
      const top2 = result.membership[1];
      const conf = confidenceBucket(
        top1?.probability ?? 0,
        top2?.probability ?? 0,
      );
      let coverage: { observed: number; total: number };
      let imp_top1_cluster = result.best.name;
      let imp_top1_share = 1;
      let imp_top2_cluster = result.ranking[1]?.name ?? '';
      let imp_top2_share = 0;
      let imp_distribution: ScoredRow['imputation_distribution'] = [
        {
          name: result.best.name,
          probability: 1,
          meanDistance: result.best.distance,
        },
      ];
      if (useImputation) {
        const r2 = result as ReturnType<typeof matchProfileWithImputation>;
        coverage = r2.coverage;
        const tops = r2.imputation.topClusters;
        imp_top1_cluster = tops[0]?.name ?? result.best.name;
        imp_top1_share = tops[0]?.probability ?? 0;
        imp_top2_cluster = tops[1]?.name ?? '';
        imp_top2_share = tops[1]?.probability ?? 0;
        imp_distribution = tops;
      } else {
        coverage = { observed: VAR_LIST.length, total: VAR_LIST.length };
      }
      const evidence = computeEvidence({
        coverageObserved: coverage.observed,
        coverageTotal: coverage.total,
        top1Share: imp_top1_share,
        top2Share: imp_top2_share,
      });
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
        coverage,
        imputation_top1_cluster: imp_top1_cluster,
        imputation_top1_share: imp_top1_share,
        imputation_top2_cluster: imp_top2_cluster,
        imputation_top2_share: imp_top2_share,
        imputation_distribution: imp_distribution,
        evidence,
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
      'coverage_observed',
      'coverage_total',
      'evidence',
      'imputation_top1_cluster',
      'imputation_top1_share',
      'imputation_top2_cluster',
      'imputation_top2_share',
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
      row.coverage_observed = String(s.coverage.observed);
      row.coverage_total = String(s.coverage.total);
      row.evidence = s.evidence;
      row.imputation_top1_cluster = s.imputation_top1_cluster;
      row.imputation_top1_share = (s.imputation_top1_share * 100).toFixed(2);
      row.imputation_top2_cluster = s.imputation_top2_cluster;
      row.imputation_top2_share = (s.imputation_top2_share * 100).toFixed(2);
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
        <DropZone onFile={handleFile} onLoadSample={handleLoadSample} />
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
            rescaling={rescaling}
            onChange={(v, h) => {
              // Changing or clearing a mapping invalidates any existing
              // rescaling rule for this variable.
              setRescaling((prev) => {
                if (!(v in prev)) return prev;
                const { [v]: _drop, ...rest } = prev;
                return rest;
              });
              if (h === '') {
                setMapping((prev) => {
                  const { [v]: _drop, ...rest } = prev;
                  return rest;
                });
              } else {
                setMapping((prev) => ({ ...prev, [v]: h }));
              }
            }}
            onApplyRescaling={(varName, invert) => {
              const col = mapping[varName];
              if (!col || !parsed) return;
              const values = parsed.rows.map((r) => r[col] ?? '');
              const sorted = precomputeECDF(values);
              if (sorted.length === 0) return;
              setRescaling((prev) => ({
                ...prev,
                [varName]: { mode: 'rank_quantile', invert, sortedCohortValues: sorted },
              }));
              setSuggestions((prev) => {
                const cur = prev[varName];
                return {
                  ...prev,
                  [varName]: {
                    header: col,
                    source: 'rank_quantile',
                    confidence: cur?.confidence ?? 0.7,
                    reason: invert
                      ? 'rank-quantile (inverted direction)'
                      : 'rank-quantile rescaling',
                  },
                };
              });
            }}
            onRemoveRescaling={(varName) => {
              setRescaling((prev) => {
                if (!(varName in prev)) return prev;
                const { [varName]: _drop, ...rest } = prev;
                return rest;
              });
              setSuggestions((prev) => {
                const cur = prev[varName];
                if (!cur || cur.source !== 'rank_quantile') return prev;
                return {
                  ...prev,
                  [varName]: {
                    header: cur.header,
                    source: 'manual',
                    confidence: 0,
                    reason: 'manual override',
                  },
                };
              });
            }}
            missingStrategy={missingStrategy}
            onChangeMissing={setMissingStrategy}
            onScore={onScore}
            canScore={!!canScore}
            mappedCount={mappedCount}
            minMapped={MIN_MAPPED}
            preflight={preflight}
            onReset={() => {
              setParsed(null);
              setMapping({});
              setSuggestions({});
              setRescaling({});
              setFilename('');
            }}
          />
        </>
      )}

      {scored && summary && validationStats && (
        <>
          {validationStats.skipped > 0 && (
            <p className="rounded-xl bg-zinc-50 border border-zinc-200 px-4 py-2.5 text-xs text-zinc-600">
              {validationStats.skipped.toLocaleString()} of{' '}
              {validationStats.total.toLocaleString()} rows skipped (validation
              issues on mapped variables).
            </p>
          )}

          <CohortDashboard
            country={country}
            rows={scored}
            unmappedColumns={unmappedColumns}
            selectedCluster={selectedCluster}
            onSelectCluster={(name) =>
              setSelectedCluster((prev) => (prev === name ? null : name))
            }
            onDownloadCsv={onDownload}
            onPrintReport={handlePrintReport}
          />

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
                setRescaling({});
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

function DropZone({
  onFile,
  onLoadSample,
}: {
  onFile: (f: File) => void;
  onLoadSample: () => void;
}) {
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
          ? 'border-blue-500 bg-blue-50'
          : 'border-zinc-300 bg-white',
      ].join(' ')}
    >
      <p className="text-base text-zinc-700">
        Drop a <code className="font-mono">.csv</code> file here, or
      </p>
      <div className="mt-4 flex flex-wrap items-center justify-center gap-3">
        <label className="inline-block cursor-pointer rounded-xl bg-slate-900 text-white px-5 py-2.5 hover:bg-slate-700 transition-colors">
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
        <button
          type="button"
          onClick={onLoadSample}
          className="rounded-xl border border-blue-500 bg-blue-50 text-blue-800 px-5 py-2.5 hover:bg-blue-100 transition-colors text-sm font-medium"
        >
          Try with sample data (30 rows)
        </button>
      </div>
      <p className="text-xs text-zinc-500 mt-6 max-w-md mx-auto leading-relaxed">
        Header row + one row per individual. Column names will be auto-mapped
        — no need to rename. Values can be numeric SHARE codes (1–5, 0/1, …)
        or natural-language labels (Yes/No, Excellent/Poor) which are
        coerced automatically. The sample dataset is a 30-row fictional
        cohort that produces a realistic Italian distribution.
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
  rescaling,
  onChange,
  onApplyRescaling,
  onRemoveRescaling,
  missingStrategy,
  onChangeMissing,
  onScore,
  canScore,
  onReset,
  mappedCount,
  minMapped,
  preflight,
}: {
  parsed: { headers: string[]; rows: Record<string, string>[] };
  mapping: Record<string, string>;
  suggestions: Record<string, ColumnSuggestion>;
  rescaling: Record<string, RescalingRule>;
  onChange: (varName: string, header: string) => void;
  onApplyRescaling: (varName: string, invert: boolean) => void;
  onRemoveRescaling: (varName: string) => void;
  missingStrategy: MissingStrategy;
  onChangeMissing: (s: MissingStrategy) => void;
  onScore: () => void;
  canScore: boolean;
  onReset: () => void;
  mappedCount: number;
  minMapped: number;
  preflight: Preflight;
}) {
  const total = VAR_LIST.length;
  const coveragePct = (mappedCount / total) * 100;
  const coverageTone =
    mappedCount >= 7
      ? 'text-blue-700'
      : mappedCount >= 5
      ? 'text-amber-700'
      : 'text-rose-600';
  const [openRescale, setOpenRescale] = useState<Set<string>>(new Set());
  const toggleRescale = (varName: string) => {
    setOpenRescale((prev) => {
      const next = new Set(prev);
      if (next.has(varName)) next.delete(varName);
      else next.add(varName);
      return next;
    });
  };
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
                ? 'bg-blue-600'
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
          const mappedCol = mapping[kv.var];
          const hasRule = !!rescaling[kv.var];
          // Auto-show the affordance when the auto-mapper had nothing
          // good, or the user has overridden it. Also show when a rule
          // already exists (so the operator can change direction or
          // remove it), or when the user explicitly opened the panel.
          const autoOpen =
            !!mappedCol &&
            (!sug || sug.source === 'none' || sug.source === 'manual');
          const showRescale = !!mappedCol && (autoOpen || hasRule || openRescale.has(kv.var));
          return (
            <div
              key={kv.var}
              className="grid grid-cols-1 sm:grid-cols-12 gap-3 items-start"
            >
              <div className="sm:col-span-5">
                <p className="text-sm font-medium text-slate-900">
                  <span className="font-mono text-xs text-blue-700 mr-2">
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
                {mappedCol && !showRescale && (
                  <button
                    type="button"
                    onClick={() => toggleRescale(kv.var)}
                    className="text-[11px] text-teal-700 hover:text-teal-900 underline-offset-2 hover:underline"
                  >
                    Rescale via rank-quantile…
                  </button>
                )}
                {showRescale && (
                  <RescalePanel
                    spec={kv}
                    columnName={mappedCol as string}
                    values={parsed.rows.map((r) => r[mappedCol as string] ?? '')}
                    rule={rescaling[kv.var]}
                    onApply={(invert) => onApplyRescaling(kv.var, invert)}
                    onRemove={() => onRemoveRescaling(kv.var)}
                    onClose={() => toggleRescale(kv.var)}
                    canClose={!autoOpen}
                  />
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
                  ? 'bg-blue-50 text-blue-800 border-blue-700'
                  : 'bg-white text-zinc-700 border-zinc-200 hover:border-slate-500',
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

      <PreflightPanel preflight={preflight} />

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
          className="rounded-full bg-slate-900 text-white px-6 py-2.5 hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          Score {parsed.rows.length.toLocaleString()} rows
        </button>
      </div>
    </article>
  );
}

function PreflightPanel({ preflight }: { preflight: Preflight }) {
  if (preflight.state === 'placeholder') {
    return (
      <div className="rounded-xl bg-zinc-50 border border-zinc-200 p-4 text-xs text-zinc-700 leading-relaxed">
        Pre-flight distributional check is unavailable: SHARE reference
        marginals not yet exported. Run{' '}
        <code className="font-mono">pipeline/v9/29_marginals_export.R</code>{' '}
        to enable Kolmogorov-Smirnov comparison of your cohort against the
        SHARE Wave 9 reference.
      </div>
    );
  }
  if (preflight.tested === 0) {
    // Nothing mapped yet — render nothing (the mapping prompt itself is the signal).
    return null;
  }
  if (!preflight.anyWarn) {
    return (
      <div className="rounded-xl bg-zinc-50 border border-zinc-200 p-4 text-xs text-zinc-700 leading-relaxed">
        Pre-flight distributional check: {preflight.tested} of{' '}
        {preflight.tested} mapped variables tested, all consistent with the
        SHARE Wave 9 reference (p ≥ 0.05). Proceed.
      </div>
    );
  }
  type FailingEntry = Exclude<PreflightEntry, { kind: 'insufficient' }>;
  const failing: FailingEntry[] = preflight.entries.filter(
    (e): e is FailingEntry =>
      e.kind !== 'insufficient' && (e.severity === 'warn' || e.severity === 'strong'),
  );
  return (
    <div className="rounded-2xl bg-amber-50 border border-amber-200 p-5 space-y-3">
      <p className="eyebrow text-amber-800">Sample-skew check</p>
      <p className="text-sm font-medium text-amber-900">
        {failing.length} of {preflight.tested} mapped variables differ from
        the SHARE Wave 9 reference.
      </p>
      <p className="text-xs text-amber-900/80 leading-relaxed">
        Your cluster assignment will be conditional on this skew. Per-row
        evidence remains valid as a within-cohort estimate; do not generalise
        the cohort distribution to the national population without the caveats
        below.
      </p>
      <details open className="text-xs">
        <summary className="cursor-pointer text-amber-900 font-medium">
          Per-variable details
        </summary>
        <ul className="mt-2 space-y-1.5">
          {failing.map((e) => {
            const tone =
              e.severity === 'strong'
                ? 'bg-rose-100 text-rose-800'
                : 'bg-amber-100 text-amber-800';
            const label =
              e.severity === 'strong' ? 'differs significantly' : 'differs';
            if (e.kind === 'ks') {
              return (
                <li key={e.var} className="flex items-baseline justify-between gap-3">
                  <span className="text-zinc-800">
                    <span className="font-mono">{e.var}</span> · D ={' '}
                    {e.D.toFixed(3)}, p = {e.p < 1e-4 ? e.p.toExponential(2) : e.p.toFixed(4)}
                  </span>
                  <span
                    className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${tone} whitespace-nowrap`}
                  >
                    {label}
                  </span>
                </li>
              );
            }
            // binary
            return (
              <li key={e.var} className="flex items-baseline justify-between gap-3">
                <span className="text-zinc-800">
                  <span className="font-mono">{e.var}</span> · cohort{' '}
                  {(e.cohortRate * 100).toFixed(0)}% vs SHARE{' '}
                  {(e.shareRate * 100).toFixed(0)}% (Δ{' '}
                  {(e.absDiff * 100).toFixed(0)} pp)
                </span>
                <span
                  className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${tone} whitespace-nowrap`}
                >
                  {label}
                </span>
              </li>
            );
          })}
        </ul>
      </details>
      <p className="text-[11px] text-amber-900/70 leading-relaxed">
        Test: two-sample Kolmogorov-Smirnov, asymptotic p-value, n_eff =
        n_cohort · n_SHARE / (n_cohort + n_SHARE). Binary variables compared
        via proportion difference instead.
      </p>
    </div>
  );
}

function RescalePanel({
  spec,
  columnName,
  values,
  rule,
  onApply,
  onRemove,
  onClose,
  canClose,
}: {
  spec: { var: string; min: number; max: number; rangeHint: string };
  columnName: string;
  values: string[];
  rule: RescalingRule | undefined;
  onApply: (invert: boolean) => void;
  onRemove: () => void;
  onClose: () => void;
  canClose: boolean;
}) {
  const [invert, setInvert] = useState<boolean>(rule?.invert ?? false);
  const numericStats = useMemo(() => {
    const nums: number[] = [];
    for (const v of values) {
      if (v === undefined || v === null) continue;
      const s = String(v).trim();
      if (s === '') continue;
      const n = Number(s);
      if (!Number.isNaN(n)) nums.push(n);
    }
    const unique = new Set(nums).size;
    return { count: nums.length, unique };
  }, [values]);
  const canApply = numericStats.count > 0;
  const fewDistinct = numericStats.unique > 0 && numericStats.unique <= 3;
  return (
    <div className="mt-1 rounded-lg border border-teal-200 bg-teal-50/60 p-3 space-y-2">
      <div className="flex items-baseline justify-between gap-2">
        <p className="text-xs font-medium text-teal-900">
          Rescale <span className="font-mono">{columnName}</span> to{' '}
          <span className="font-mono">{spec.var}</span> (SHARE range {spec.min}
          –{spec.max})
        </p>
        {canClose && (
          <button
            type="button"
            onClick={onClose}
            className="text-[11px] text-zinc-500 hover:text-slate-900"
          >
            close
          </button>
        )}
      </div>
      <p className="text-[11px] text-teal-900/80 leading-relaxed">
        Map by rank: lowest values in your column become the lowest SHARE
        codes, highest become highest. Order-preserving.
      </p>
      <p className="text-[11px] text-zinc-600 italic">
        {spec.var}: {spec.rangeHint}
      </p>
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-[11px] text-zinc-600">Direction:</span>
        <button
          type="button"
          onClick={() => setInvert(false)}
          className={[
            'rounded-full px-3 py-1 text-[11px] border transition-colors',
            !invert
              ? 'bg-teal-700 text-white border-teal-700'
              : 'bg-white text-zinc-700 border-zinc-300 hover:border-teal-500',
          ].join(' ')}
        >
          {columnName} high → SHARE high
        </button>
        <button
          type="button"
          onClick={() => setInvert(true)}
          className={[
            'rounded-full px-3 py-1 text-[11px] border transition-colors',
            invert
              ? 'bg-teal-700 text-white border-teal-700'
              : 'bg-white text-zinc-700 border-zinc-300 hover:border-teal-500',
          ].join(' ')}
        >
          {columnName} high → SHARE low
        </button>
      </div>
      {!canApply && (
        <p className="text-[11px] text-rose-700">
          No numeric values to rescale.
        </p>
      )}
      {canApply && fewDistinct && (
        <p className="text-[11px] text-amber-700">
          Only {numericStats.unique} distinct values — rank mapping will
          produce only {numericStats.unique} bins.
        </p>
      )}
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={() => onApply(invert)}
          disabled={!canApply}
          className="rounded-lg bg-teal-700 text-white text-xs px-3 py-1.5 hover:bg-teal-800 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          {rule ? 'Update rescaling' : 'Apply rescaling'}
        </button>
        {rule && (
          <button
            type="button"
            onClick={onRemove}
            className="rounded-lg border border-zinc-300 bg-white text-xs px-3 py-1.5 text-zinc-700 hover:border-rose-400 hover:text-rose-700 transition-colors"
          >
            Remove
          </button>
        )}
        {rule && (
          <span className="text-[11px] text-teal-700">
            Active · {rule.invert ? 'inverted' : 'direct'} · n=
            {rule.sortedCohortValues.length}
          </span>
        )}
      </div>
    </div>
  );
}

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
  // Hide the imputation columns entirely when every row has full
  // coverage — preserves the visual surface of the sample-data path.
  const showImputationCols = scored.some((s) => s.coverage.observed < s.coverage.total);
  const [openImpRow, setOpenImpRow] = useState<number | null>(null);
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-3">
      <div className="flex items-baseline justify-between">
        <p className="eyebrow">Per-row prediction</p>
        {scored.length > 10 && (
          <button
            type="button"
            onClick={onToggle}
            className="text-xs text-blue-700 hover:text-blue-900"
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
              <th className="px-2 py-1.5 font-medium">Evidence</th>
              <th className="px-2 py-1.5 font-medium text-right">Top-1</th>
              <th className="px-2 py-1.5 font-medium">Runner-up</th>
              <th className="px-2 py-1.5 font-medium text-right">Top-2</th>
              <th className="px-2 py-1.5 font-medium text-right">Dist.</th>
              <th className="px-2 py-1.5 font-medium text-right">Pctile</th>
              {showImputationCols && (
                <>
                  <th className="px-2 py-1.5 font-medium text-right">Coverage</th>
                  <th className="px-2 py-1.5 font-medium text-right">Imp. top-1</th>
                </>
              )}
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
                    className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${EVIDENCE_COLORS[s.evidence]}`}
                  >
                    {s.evidence}
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
                {showImputationCols && (
                  <>
                    <td className="px-2 py-1.5 text-right tabular-nums text-zinc-600">
                      {s.coverage.observed}/{s.coverage.total}
                    </td>
                    <td className="px-2 py-1.5 text-right tabular-nums text-zinc-700 relative">
                      <button
                        type="button"
                        onClick={() => setOpenImpRow((p) => (p === i ? null : i))}
                        className="rounded px-1 hover:bg-zinc-100"
                        title="Show imputation distribution"
                      >
                        {(s.imputation_top1_share * 100).toFixed(0)}%
                      </button>
                      {openImpRow === i && s.imputation_distribution.length > 0 && (
                        <div className="absolute z-10 right-0 mt-1 w-56 rounded-lg border border-zinc-200 bg-white shadow-lg p-2 text-left">
                          <p className="text-[10px] uppercase tracking-wider text-zinc-500 mb-1">
                            Imputation distribution
                          </p>
                          <ul className="space-y-1">
                            {s.imputation_distribution.slice(0, 5).map((c) => (
                              <li
                                key={c.name}
                                className="flex items-baseline justify-between gap-2 text-xs"
                              >
                                <span className="text-slate-900 truncate">{c.name}</span>
                                <span className="tabular-nums text-zinc-600">
                                  {(c.probability * 100).toFixed(0)}%
                                </span>
                              </li>
                            ))}
                          </ul>
                        </div>
                      )}
                    </td>
                  </>
                )}
                <td className="px-2 py-1.5 text-zinc-700">
                  {s.twin_country_profile}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-zinc-500">
        <span className="font-medium">Evidence</span> = Strong (score ≥ 7),
        Moderate (4.5–7), Weak (&lt; 4.5), where score combines coverage and
        imputation top-1/top-2 share on a 0–10 scale.{' '}
        <span className="font-medium">Pctile</span> = within-cohort percentile
        of the row's distance to its centroid (high = atypical). Download to
        get full z-scores per row.
      </p>
    </article>
  );
}
