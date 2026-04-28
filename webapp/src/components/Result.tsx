import { useMemo, useState } from 'react';
import type { CentroidsJson, Country } from '../lib/profiler';
import { matchProfile } from '../lib/profiler';
import {
  clusterTraits,
  healthcareFingerprint,
  passportFor,
  welfareGap,
  withinClusterPercentile,
  type HealthcareIndicator,
  type WelfareGapDimension,
} from '../lib/cluster-insights';

type Narratives = {
  italy: Record<string, string>;
  sweden: Record<string, string>;
};

type Props = {
  country: Country;
  answers: Record<string, number>;
  data: CentroidsJson;
  narratives: Narratives;
  onRestart: () => void;
};

const Z_CAP = 3;

export default function Result({
  country,
  answers,
  data,
  narratives,
  onRestart,
}: Props) {
  const [showAll, setShowAll] = useState(false);
  const result = useMemo(
    () => matchProfile(country, answers, data),
    [country, answers, data],
  );
  const { best, ranking, membership, twinName } = result;

  const passport = passportFor(country, best.name);
  const traits = useMemo(
    () => clusterTraits(country, best.name, data),
    [country, best.name, data],
  );
  const within = useMemo(
    () => withinClusterPercentile(best.zScores, country, best.name, data),
    [best.zScores, country, best.name, data],
  );
  const fingerprint = useMemo(
    () => healthcareFingerprint(country, best.name),
    [country, best.name],
  );
  const gap = useMemo(() => welfareGap(country, best.name), [country, best.name]);

  const otherCountry: Country = country === 'italy' ? 'sweden' : 'italy';
  const narrative = narratives[country][best.name] ?? '';
  const twinNarrative = twinName ? narratives[otherCountry][twinName] : '';
  const keyVars = data.key_variables;

  return (
    <section className="space-y-12 max-w-3xl">
      <header className="space-y-4">
        <p className="eyebrow">{country} · closest profile</p>
        <h1 className="display-1 text-slate-900">{best.name}</h1>
        {passport && (
          <p className="display-3 text-slate-900">{passport.headline}</p>
        )}
        {passport?.tagline && (
          <p className="text-base text-zinc-600 italic max-w-2xl">
            {passport.tagline}
          </p>
        )}
        {narrative && (
          <p className="text-lg text-zinc-700 leading-relaxed">{narrative}</p>
        )}
      </header>

      {(traits.strengths.length > 0 || traits.pressurePoints.length > 0) && (
        <article className="rounded-2xl bg-white border border-zinc-200 p-7 space-y-5">
          <p className="eyebrow">Cluster signature</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <p className="text-sm font-medium text-emerald-700 mb-2">
                Strengths
              </p>
              {traits.strengths.length === 0 ? (
                <p className="text-sm text-zinc-500">
                  No dimension scores notably above the country mean.
                </p>
              ) : (
                <ul className="space-y-1.5">
                  {traits.strengths.map((t) => (
                    <li
                      key={t.variable}
                      className="text-sm text-zinc-700 flex items-baseline justify-between"
                    >
                      <span>{t.label}</span>
                      <span className="text-xs tabular-nums text-emerald-700 font-medium">
                        z = {t.zScore >= 0 ? '+' : ''}
                        {t.zScore.toFixed(2)}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
            <div>
              <p className="text-sm font-medium text-rose-700 mb-2">
                Pressure points
              </p>
              {traits.pressurePoints.length === 0 ? (
                <p className="text-sm text-zinc-500">
                  No dimension scores notably below the country mean.
                </p>
              ) : (
                <ul className="space-y-1.5">
                  {traits.pressurePoints.map((t) => (
                    <li
                      key={t.variable}
                      className="text-sm text-zinc-700 flex items-baseline justify-between"
                    >
                      <span>{t.label}</span>
                      <span className="text-xs tabular-nums text-rose-700 font-medium">
                        z = {t.zScore >= 0 ? '+' : ''}
                        {t.zScore.toFixed(2)}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
          <p className="text-xs text-zinc-500">
            Cluster centroid scored against the country mean. A z-score above
            +0.25 (or below −0.25) on an oriented dimension is reported as a
            strength (or pressure point).
          </p>
        </article>
      )}

      {passport && passport.action_signals.length > 0 && (
        <article className="rounded-2xl bg-white border border-zinc-200 p-7 space-y-3">
          <p className="eyebrow">What this cluster makes visible</p>
          <ul className="space-y-3">
            {passport.action_signals.map((s, i) => (
              <li key={i} className="text-sm text-zinc-700 leading-relaxed flex gap-3">
                <span className="text-emerald-700 font-mono text-xs tabular-nums mt-0.5">
                  {String(i + 1).padStart(2, '0')}
                </span>
                <span>{s}</span>
              </li>
            ))}
          </ul>
        </article>
      )}

      <article className="rounded-2xl bg-white border border-zinc-200 p-7 space-y-5">
        <header>
          <p className="eyebrow">Where you stand within the cluster</p>
          <p className="text-sm text-zinc-600 leading-relaxed mt-2 max-w-2xl">
            Percentile of your responses against an approximated within-cluster
            distribution. 50 means you sit at the cluster centroid; tails
            indicate you would be at the edge of this profile.
          </p>
        </header>
        <div className="space-y-2">
          {within.map((w) => (
            <div key={w.variable} className="grid grid-cols-12 gap-3 items-center">
              <div className="col-span-5 text-sm text-zinc-700 truncate">
                {w.label}
              </div>
              <div className="col-span-6 relative h-3 bg-zinc-100 rounded-full overflow-hidden">
                <div className="absolute inset-y-0 left-1/2 w-px bg-zinc-300" />
                <div
                  className="absolute inset-y-0 left-0 bg-emerald-500/30 rounded-full"
                  style={{ width: `${Math.max(2, w.pct).toFixed(1)}%` }}
                />
                <div
                  className="absolute inset-y-0 w-1 bg-slate-900 rounded-full"
                  style={{ left: `calc(${w.pct.toFixed(1)}% - 2px)` }}
                />
              </div>
              <div className="col-span-1 text-right text-xs tabular-nums text-zinc-700 font-medium">
                p{w.pct.toFixed(0)}
              </div>
            </div>
          ))}
        </div>
      </article>

      {fingerprint.length > 0 && (
        <article className="rounded-2xl bg-white border border-zinc-200 p-7 space-y-5">
          <p className="eyebrow">Healthcare engagement of this cluster</p>
          <p className="text-sm text-zinc-600 leading-relaxed max-w-2xl">
            Observed mean for the cluster vs the country average — what people
            in this profile actually do, not what is expected of them.
          </p>
          <div className="space-y-2.5">
            {fingerprint.map((f) => (
              <FingerprintRow key={f.key} f={f} />
            ))}
          </div>
        </article>
      )}

      {gap && (
        <article className="rounded-2xl bg-emerald-50 border border-emerald-200 p-7 space-y-4">
          <p className="eyebrow text-emerald-700">
            Welfare-state translation · {gap.pairLabel} matched pair
          </p>
          <p className="display-3 text-slate-900">
            In {country === 'italy' ? 'Sweden' : 'Italy'}, this cluster matches{' '}
            <span className="text-emerald-700">
              {country === 'italy' ? gap.swedishProfile : gap.italianProfile}
            </span>
            .
          </p>
          {twinNarrative && (
            <p className="text-sm text-zinc-700 leading-relaxed">
              {twinNarrative}
            </p>
          )}
          <div className="space-y-2.5 pt-2">
            {gap.dimensions.slice(0, 5).map((d) => (
              <GapRow key={d.dimension} d={d} country={country} />
            ))}
          </div>
        </article>
      )}

      {!gap && passport && passport.welfare_pair === null && (
        <article className="rounded-2xl bg-zinc-50 border border-zinc-200 p-7 space-y-3">
          <p className="eyebrow">Country-specific cluster</p>
          <p className="text-sm text-zinc-700 leading-relaxed">
            This cluster has no analogue in the matched-pair design — it is a{' '}
            {country === 'italy' ? 'Italy-specific' : 'Sweden-specific'}{' '}
            structural finding. Universalist welfare in Sweden redistributes
            this profile across other clusters; the segmentation does not
            recover it.
          </p>
        </article>
      )}

      <article className="rounded-2xl bg-white border border-zinc-200 p-7 space-y-5">
        <header>
          <p className="eyebrow">Membership distribution</p>
          <p className="text-sm text-zinc-600 leading-relaxed mt-2 max-w-2xl">
            Soft assignment over all profiles — the output an operator
            consumes for propensity scoring.
          </p>
        </header>
        <div className="space-y-2.5">
          {membership.map((m, i) => (
            <div
              key={m.name}
              className="grid grid-cols-12 gap-3 items-center"
            >
              <div
                className={[
                  'col-span-5 text-sm truncate',
                  i === 0 ? 'font-semibold text-slate-900' : 'text-zinc-600',
                ].join(' ')}
              >
                {m.name}
              </div>
              <div className="col-span-6 relative h-3 bg-zinc-100 rounded-full overflow-hidden">
                <div
                  className={[
                    'absolute inset-y-0 left-0 rounded-full',
                    i === 0 ? 'bg-emerald-600' : 'bg-zinc-400',
                  ].join(' ')}
                  style={{ width: `${(m.probability * 100).toFixed(1)}%` }}
                />
              </div>
              <div className="col-span-1 text-right text-xs tabular-nums text-zinc-700 font-medium">
                {(m.probability * 100).toFixed(0)}%
              </div>
            </div>
          ))}
        </div>
      </article>

      <article className="rounded-2xl bg-white border border-zinc-200 p-7 space-y-5">
        <p className="eyebrow">Your z-scores · 10 quiz dimensions</p>
        <div className="space-y-2.5">
          {keyVars.map((kv) => {
            const z = best.zScores[kv.var] ?? 0;
            const capped = Math.max(-Z_CAP, Math.min(Z_CAP, z));
            const pct = (Math.abs(capped) / Z_CAP) * 50;
            const isPos = z >= 0;
            return (
              <div
                key={kv.var}
                className="grid grid-cols-12 gap-3 items-center"
              >
                <div
                  className="col-span-3 text-sm text-zinc-700 truncate"
                  title={kv.label}
                >
                  {kv.var}
                </div>
                <div className="col-span-8 relative h-4 bg-zinc-100 rounded">
                  <div className="absolute inset-y-0 left-1/2 w-px bg-zinc-300" />
                  <div
                    className={[
                      'absolute inset-y-0 rounded',
                      isPos
                        ? 'bg-emerald-600 left-1/2'
                        : 'bg-rose-500 right-1/2',
                    ].join(' ')}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <div className="col-span-1 text-right text-xs tabular-nums text-zinc-600">
                  {z >= 0 ? '+' : ''}
                  {z.toFixed(1)}
                </div>
              </div>
            );
          })}
        </div>
        <p className="text-xs text-zinc-500 leading-relaxed">
          Standardised against the country mean. Display capped at ±{Z_CAP}.
        </p>
      </article>

      <details
        className="rounded-2xl bg-white border border-zinc-200 p-6"
        open={showAll}
      >
        <summary
          className="cursor-pointer text-sm font-medium text-zinc-700 select-none"
          onClick={(e) => {
            e.preventDefault();
            setShowAll((v) => !v);
          }}
        >
          {showAll ? 'Hide' : 'Show'} all profiles ranked by distance
        </summary>
        <ul className="mt-4 space-y-1.5">
          {ranking.map((m, i) => (
            <li
              key={m.name}
              className={[
                'flex items-center justify-between rounded-lg px-3 py-2',
                i === 0
                  ? 'bg-emerald-50 font-medium text-slate-900'
                  : 'text-zinc-700',
              ].join(' ')}
            >
              <span>
                {i + 1}. {m.name}
              </span>
              <span className="text-xs tabular-nums text-zinc-500">
                d = {m.distance.toFixed(2)}
              </span>
            </li>
          ))}
        </ul>
      </details>

      <div className="flex justify-end">
        <button
          type="button"
          onClick={onRestart}
          className="rounded-xl border border-zinc-300 px-5 py-2.5 text-zinc-700 hover:bg-white hover:text-slate-900 transition-colors"
        >
          Start over
        </button>
      </div>
    </section>
  );
}

function FingerprintRow({ f }: { f: HealthcareIndicator }) {
  const fmt = (v: number) =>
    f.unit === 'pct' ? `${(v * 100).toFixed(0)}%` : v.toFixed(1);
  const cohortDelta = f.cluster - f.national;
  const deltaDir =
    f.orientation === 'higher_is_engaged'
      ? cohortDelta >= 0
        ? 'up_good'
        : 'down_bad'
      : cohortDelta >= 0
      ? 'up_bad'
      : 'down_good';
  const deltaTone =
    deltaDir === 'up_good' || deltaDir === 'down_good'
      ? 'text-emerald-700'
      : 'text-rose-600';
  const max = Math.max(f.cluster, f.national, 0.0001);
  return (
    <div className="grid grid-cols-12 gap-3 items-center">
      <div className="col-span-5 text-sm text-zinc-700 truncate">{f.label}</div>
      <div className="col-span-5 space-y-1">
        <div className="relative h-2 bg-zinc-100 rounded-full overflow-hidden">
          <div
            className="absolute inset-y-0 left-0 bg-emerald-600 rounded-full"
            style={{ width: `${(f.cluster / max) * 100}%` }}
          />
        </div>
        <div className="relative h-1.5 bg-zinc-50 rounded-full overflow-hidden">
          <div
            className="absolute inset-y-0 left-0 bg-zinc-400 rounded-full"
            style={{ width: `${(f.national / max) * 100}%` }}
          />
        </div>
      </div>
      <div className="col-span-2 text-right text-xs tabular-nums">
        <div className="text-slate-900 font-medium">{fmt(f.cluster)}</div>
        <div className={`${deltaTone}`}>
          {f.unit === 'pct'
            ? `${cohortDelta >= 0 ? '+' : ''}${(cohortDelta * 100).toFixed(0)}pp`
            : `${cohortDelta >= 0 ? '+' : ''}${cohortDelta.toFixed(1)}`}
        </div>
      </div>
    </div>
  );
}

function GapRow({
  d,
  country,
}: {
  d: WelfareGapDimension;
  country: Country;
}) {
  const userValue = country === 'italy' ? d.italyValue : d.swedenValue;
  const twinValue = country === 'italy' ? d.swedenValue : d.italyValue;
  const gap = country === 'italy' ? d.gap : -d.gap;
  const fmtVal = (v: number) => {
    if (d.unit === 'pct') return `${(v * 100).toFixed(0)}%`;
    if (d.unit === 'score') return v.toFixed(1);
    return v.toFixed(2);
  };
  const fmtGap = (v: number) => {
    if (d.unit === 'pct') return `${v >= 0 ? '+' : ''}${(v * 100).toFixed(0)}pp`;
    if (d.unit === 'score') return `${v >= 0 ? '+' : ''}${v.toFixed(1)}`;
    return `${v >= 0 ? '+' : ''}${v.toFixed(2)}`;
  };
  const tone = gap >= 0 ? 'text-emerald-700' : 'text-rose-600';
  return (
    <div className="grid grid-cols-12 gap-3 items-baseline">
      <div className="col-span-5 text-sm text-zinc-700">{d.label}</div>
      <div className="col-span-3 text-right text-sm tabular-nums text-slate-900">
        {fmtVal(userValue)}
      </div>
      <div className="col-span-2 text-right text-sm tabular-nums text-zinc-600">
        {fmtVal(twinValue)}
      </div>
      <div className={`col-span-2 text-right text-sm tabular-nums font-medium ${tone}`}>
        {fmtGap(gap)}
      </div>
    </div>
  );
}
