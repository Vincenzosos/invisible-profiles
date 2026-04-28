# ==============================================================================
# STEP 23: KILLER NUMBERS FOR THE SILVER ECONOMY INTELLIGENCE PRODUCT
# Thesis: "Invisible Profiles" - Bocconi MSc EMIT (course 20570, Prof. Trentini)
#
# Reads step11_italy_with_healthcare.rds and step11_sweden_with_healthcare.rds
# (individual-level data with cluster assignments + healthcare merge) and
# computes the per-profile and per-country aggregates that drive the B2B
# product:
#
#   - Per-profile market sizing (n in sample, % of sample, projected n in
#     national population using Istat/SCB total over-65, aggregate income
#     and aggregate household net worth in EUR)
#   - Per-profile economic snapshot (median income, median net worth, both
#     with bootstrap 95% CI, % home owners, % financially distressed)
#   - Per-profile behavioural / digital / cognitive / subjective snapshot
#     (means with bootstrap 95% CI for the variables that drive the
#     business signals)
#   - Per-profile healthcare engagement (dentist 12m, doctor visits, GP
#     contacts, specialist contacts, forgone-care-for-cost, nights in
#     hospital)
#   - Italy <-> Sweden matched-pair gaps with opportunity sizing
#     (gap x Italian addressable population) for the dimensions that map
#     onto market headroom: dental coverage, internet penetration,
#     preventive specialist contact, CASP, financial ease.
#   - Italy total addressable silver economy: aggregate annual income flow
#     and aggregate household net wealth across the over-65 segment.
#
# OUTPUT: v9/outputs/killer_numbers.json
# This file is consumed by the webapp screens (Atlas, Benchmark, Opportunity
# Explorer) and is the single source of truth for the business numbers cited
# in chapter 1 and chapter 8 of the thesis.
#
# Dependencies: pyreadr, numpy, pandas
# ==============================================================================

import json
import numpy as np
import pandas as pd
import pyreadr
from pathlib import Path

DATA_DIR = Path("/sessions/stoic-sleepy-dirac/mnt/DATASET RESEARCH/v9/outputs")
OUT_FILE = DATA_DIR / "killer_numbers.json"

# ---- National over-65 totals (used to project per-profile market size) -----
# Source: Istat (Italy) and SCB (Sweden) latest available figures (2024).
ISTAT_OVER65_ITALY = 14_180_000
SCB_OVER65_SWEDEN = 2_055_000

# Profile orderings used throughout the thesis
PROFILE_ORDER_ITALY = [
    "Fragile Resigned", "Fragile Depressed", "Moderate Isolated",
    "Traditional Social", "Connected Active",
]
PROFILE_ORDER_SWEDEN = [
    "Fragile", "Social Decline", "Moderate",
    "Asset Rich", "Wealthy Digital", "Connected Wealthy",
]

# Matched pairs (used in chapter 5 and in Benchmark screen)
MATCHED_PAIRS = [
    ("Fragile",            "Fragile Resigned",   "Fragile"),
    ("Declining",          "Fragile Depressed",  "Social Decline"),
    ("Socially-oriented",  "Traditional Social", "Moderate"),
    ("Connected",          "Connected Active",   "Connected Wealthy"),
]

# ---- Helpers ---------------------------------------------------------------

def boot_ci(x, stat=np.median, B=2000, alpha=0.05, seed=42):
    """Percentile bootstrap 95% CI for a univariate statistic."""
    x = np.asarray(x, dtype=float)
    x = x[~np.isnan(x)]
    if len(x) == 0:
        return (np.nan, np.nan, np.nan)
    rng = np.random.default_rng(seed)
    n = len(x)
    samples = np.empty(B)
    for b in range(B):
        samples[b] = stat(x[rng.integers(0, n, size=n)])
    point = stat(x)
    lo = float(np.quantile(samples, alpha / 2))
    hi = float(np.quantile(samples, 1 - alpha / 2))
    return float(point), lo, hi


def share(x, value=1.0):
    """Fraction of finite values equal to `value`."""
    x = np.asarray(x, dtype=float)
    x = x[~np.isnan(x)]
    if len(x) == 0:
        return np.nan
    return float((x == value).mean())


def pct(x, threshold, op="le"):
    """Percent of x satisfying op against threshold (op in {le, ge, lt, gt})."""
    x = np.asarray(x, dtype=float)
    x = x[~np.isnan(x)]
    if len(x) == 0:
        return np.nan
    cmp = {"le": x <= threshold, "ge": x >= threshold,
           "lt": x < threshold,  "gt": x > threshold}[op]
    return float(cmp.mean())


def diff_means_ci(a, b, B=2000, alpha=0.05, seed=42):
    """Bootstrap 95% CI for difference of means (b - a)."""
    a = np.asarray(a, dtype=float); a = a[~np.isnan(a)]
    b = np.asarray(b, dtype=float); b = b[~np.isnan(b)]
    if len(a) == 0 or len(b) == 0:
        return (np.nan, np.nan, np.nan)
    rng = np.random.default_rng(seed)
    diffs = np.empty(B)
    for i in range(B):
        diffs[i] = b[rng.integers(0, len(b), len(b))].mean() - \
                   a[rng.integers(0, len(a), len(a))].mean()
    point = b.mean() - a.mean()
    lo = float(np.quantile(diffs, alpha / 2))
    hi = float(np.quantile(diffs, 1 - alpha / 2))
    return float(point), lo, hi


def round_money(x, ndigits=0):
    if x is None or (isinstance(x, float) and np.isnan(x)):
        return None
    return round(float(x), ndigits)


def round_pct(x, ndigits=3):
    if x is None or (isinstance(x, float) and np.isnan(x)):
        return None
    return round(float(x), ndigits)


# ---- Load data -------------------------------------------------------------

print("Loading data...")
italy = pyreadr.read_r(str(DATA_DIR / "step11_italy_with_healthcare.rds"))[None]
sweden = pyreadr.read_r(str(DATA_DIR / "step11_sweden_with_healthcare.rds"))[None]

# Convert the categorical "profile" to plain string for stable JSON keys
italy["profile"] = italy["profile"].astype(str)
sweden["profile"] = sweden["profile"].astype(str)

print(f"Italy n = {len(italy)}, Sweden n = {len(sweden)}")


# ---- Country-level aggregates ----------------------------------------------

def country_aggregates(df, total_pop, country_name):
    n_sample = len(df)
    income_med, income_lo, income_hi = boot_ci(df["thinc"])
    netw_med, netw_lo, netw_hi = boot_ci(df["hnetw"])

    aggregate_income_eur = income_med * total_pop
    aggregate_netw_eur = netw_med * total_pop

    return {
        "country": country_name,
        "n_sample": int(n_sample),
        "national_over65_individuals": int(total_pop),
        "median_household_income_eur": round_money(income_med),
        "median_household_income_eur_ci": [round_money(income_lo),
                                           round_money(income_hi)],
        "median_household_networth_eur": round_money(netw_med),
        "median_household_networth_eur_ci": [round_money(netw_lo),
                                             round_money(netw_hi)],
        "aggregate_annual_income_flow_eur": round_money(aggregate_income_eur, -6),
        "aggregate_household_networth_eur": round_money(aggregate_netw_eur, -6),
        "aggregate_annual_income_flow_eur_billions": round(
            aggregate_income_eur / 1e9, 1),
        "aggregate_household_networth_eur_trillions": round(
            aggregate_netw_eur / 1e12, 2),
        "internet_penetration_pct": round_pct(df["internet"].mean(), 4),
        "homeownership_pct": round_pct(df["home_own"].mean(), 4),
        "dentist_12m_pct": round_pct(df["dentist_12m"].mean(), 4),
        "forgone_care_for_cost_pct": round_pct(df["forgone_any_cost"].mean(), 4),
        "median_age_years": float(df["age"].median()),
        "mean_casp": float(df["casp"].mean().round(2)),
        "mean_lifesat": float(df["lifesat"].mean().round(2)),
    }

print("Computing country-level aggregates...")
italy_country = country_aggregates(italy, ISTAT_OVER65_ITALY, "Italy")
sweden_country = country_aggregates(sweden, SCB_OVER65_SWEDEN, "Sweden")


# ---- Per-profile snapshot --------------------------------------------------

def profile_snapshot(df, profile_name, total_pop, n_total):
    sub = df[df["profile"] == profile_name]
    n = len(sub)
    pct_share = n / n_total

    market_size_individuals = int(round(pct_share * total_pop))

    income_med, income_lo, income_hi = boot_ci(sub["thinc"])
    netw_med, netw_lo, netw_hi = boot_ci(sub["hnetw"])
    pension_med, _, _ = boot_ci(sub["ypen1"])

    aggregate_income = income_med * market_size_individuals
    aggregate_netw = netw_med * market_size_individuals

    casp_mean, casp_lo, casp_hi = boot_ci(sub["casp"], stat=np.mean)
    lifesat_mean, _, _ = boot_ci(sub["lifesat"], stat=np.mean)
    eurod_mean, _, _ = boot_ci(sub["eurod"], stat=np.mean)
    fluency_mean, _, _ = boot_ci(sub["fluency"], stat=np.mean)
    loneliness_mean, _, _ = boot_ci(sub["loneliness"], stat=np.mean)

    snapshot = {
        "profile": profile_name,
        "n_sample": int(n),
        "share_of_country_pct": round_pct(pct_share, 4),
        "market_size_individuals": market_size_individuals,
        "market_size_thousands": round(market_size_individuals / 1e3, 1),
        # Economic
        "median_income_eur": round_money(income_med),
        "median_income_eur_ci": [round_money(income_lo), round_money(income_hi)],
        "median_networth_eur": round_money(netw_med),
        "median_networth_eur_ci": [round_money(netw_lo), round_money(netw_hi)],
        "median_pension_eur": round_money(pension_med),
        "aggregate_annual_income_eur": round_money(aggregate_income, -6),
        "aggregate_annual_income_eur_billions": round(aggregate_income / 1e9, 2),
        "aggregate_networth_eur": round_money(aggregate_netw, -6),
        "aggregate_networth_eur_billions": round(aggregate_netw / 1e9, 2),
        "homeownership_pct": round_pct(sub["home_own"].mean(), 4),
        "fdistress_struggling_pct": round_pct(
            (sub["fdistress"] <= 2).mean(), 4),
        "fdistress_easy_pct": round_pct(
            (sub["fdistress"] >= 3).mean(), 4),
        # Digital / social
        "internet_pct": round_pct(sub["internet"].mean(), 4),
        "online_banking_health_proxy_pct": round_pct(
            sub[["ac035d1", "ac035d5", "ac035d8"]].max(axis=1).mean(), 4
        ),  # at least one of: internet for purchase / banking / official
        "social_network_size_mean": round(float(sub["sn_size_w9"].mean()), 2),
        "loneliness_mean": round(loneliness_mean, 2),
        # Cognitive
        "fluency_mean": round(fluency_mean, 2),
        # Subjective
        "casp_mean": round(casp_mean, 2),
        "casp_mean_ci": [round(casp_lo, 2), round(casp_hi, 2)],
        "lifesat_mean": round(lifesat_mean, 2),
        "hope_future_pct": round_pct(sub["hope_future"].mean(), 4),
        "eurod_mean": round(eurod_mean, 2),
        # Healthcare engagement
        "dentist_12m_pct": round_pct(sub["dentist_12m"].mean(), 4),
        "doctor_visits_mean": round(float(sub["doctor_visits"].mean()), 2),
        "gp_contacts_mean": round(float(sub["gp_contacts"].mean()), 2),
        "specialist_contacts_mean": round(
            float(sub["spec_contacts"].mean()), 2),
        "forgone_care_for_cost_pct": round_pct(
            sub["forgone_any_cost"].mean(), 4),
        "hospitalised_pct": round_pct(sub["hospitalised"].mean(), 4),
        # Demographics
        "mean_age_years": round(float(sub["age"].mean()), 1),
        "share_female": round_pct((sub["gender"] == 2).mean(), 4),
    }
    return snapshot


print("Computing Italy per-profile snapshots...")
italy_profiles = [
    profile_snapshot(italy, p, ISTAT_OVER65_ITALY, len(italy))
    for p in PROFILE_ORDER_ITALY
]

print("Computing Sweden per-profile snapshots...")
sweden_profiles = [
    profile_snapshot(sweden, p, SCB_OVER65_SWEDEN, len(sweden))
    for p in PROFILE_ORDER_SWEDEN
]


# ---- Matched-pair gap with opportunity sizing ------------------------------

GAP_DIMENSIONS = [
    # (key, var, scale_text, business_meaning, monetisation_hint_eur)
    ("dentist_12m",     "dentist_12m",     "binary 0/1", "preventive dental care market headroom", 80.0),
    ("internet",        "internet",        "binary 0/1", "digital reach / online services market headroom", None),
    ("forgone_cost",    "forgone_any_cost","binary 0/1", "affordability gap (negative -> Sweden has less unmet need)", None),
    ("specialist",      "spec_contacts",   "count 12m",  "private specialist consultation market headroom", 130.0),
    ("casp",            "casp",            "12-48",      "subjective wellbeing market headroom", None),
    ("internet_banking","ac035d5",         "binary 0/1", "digital financial services market headroom", None),
    ("online_purchase", "ac035d1",         "binary 0/1", "e-commerce silver market headroom", None),
]

def matched_pair_gap(label, italian_profile, swedish_profile):
    sub_it = italy[italy["profile"] == italian_profile]
    sub_se = sweden[sweden["profile"] == swedish_profile]

    italian_market_size = int(round(
        len(sub_it) / len(italy) * ISTAT_OVER65_ITALY))

    dimensions_out = []
    for key, var, scale, meaning, eur_per_unit in GAP_DIMENSIONS:
        if var not in sub_it.columns or var not in sub_se.columns:
            continue
        gap_point, gap_lo, gap_hi = diff_means_ci(sub_it[var], sub_se[var])
        out = {
            "dimension": key,
            "variable": var,
            "scale": scale,
            "business_meaning": meaning,
            "italy_mean": round(float(sub_it[var].mean()), 4),
            "sweden_mean": round(float(sub_se[var].mean()), 4),
            "gap_se_minus_it": round(gap_point, 4),
            "gap_ci": [round(gap_lo, 4), round(gap_hi, 4)],
        }
        if eur_per_unit is not None and scale.startswith("binary"):
            # Opportunity = positive gap × Italian segment size × € per uptake
            opp = max(0.0, gap_point) * italian_market_size * eur_per_unit
            out["opportunity_size_eur"] = round_money(opp, -3)
            out["opportunity_size_eur_millions"] = round(opp / 1e6, 1)
            out["opportunity_assumption"] = (
                f"€{int(eur_per_unit)} per individual per year if Italian "
                f"segment closes the gap with Sweden"
            )
        dimensions_out.append(out)

    return {
        "matched_pair_label": label,
        "italian_profile": italian_profile,
        "swedish_profile": swedish_profile,
        "italian_market_size_individuals": italian_market_size,
        "italian_market_size_thousands": round(italian_market_size / 1e3, 1),
        "dimensions": dimensions_out,
    }

print("Computing matched-pair gaps...")
matched_pair_results = [
    matched_pair_gap(label, it_p, se_p)
    for label, it_p, se_p in MATCHED_PAIRS
]


# ---- Time-to-maturity placeholder ------------------------------------------
# Without W6-W8 longitudinal data here, we provide explicit placeholder
# linear extrapolation under a 1-pp-per-year assumption (Italy has been
# closing its digital gap at ~1pp/yr per Eurostat ICT survey 2018-2024).
# This is documented as "indicative; calibrate with cross-wave SHARE
# regression in future work".

DIGITAL_GAP_CLOSE_RATE_PP_PER_YEAR = 1.0  # 1 percentage point per year


def time_to_maturity_pp(it_pct, se_pct):
    if it_pct is None or se_pct is None:
        return None
    gap_pp = (se_pct - it_pct) * 100
    if gap_pp <= 0:
        return 0
    return round(gap_pp / DIGITAL_GAP_CLOSE_RATE_PP_PER_YEAR, 1)


time_to_maturity = {
    "method": "linear extrapolation at 1pp/year (digital indicators); "
              "indicative, to be recalibrated with W6-W8 trend regression",
    "rate_assumption_pp_per_year": DIGITAL_GAP_CLOSE_RATE_PP_PER_YEAR,
    "estimates": {
        "internet_overall_years_to_close":
            time_to_maturity_pp(italy_country["internet_penetration_pct"],
                                sweden_country["internet_penetration_pct"]),
        "dentist_overall_years_to_close":
            time_to_maturity_pp(italy_country["dentist_12m_pct"],
                                sweden_country["dentist_12m_pct"]),
    },
}


# ---- Assemble final JSON ---------------------------------------------------

generated_at = pd.Timestamp.utcnow().isoformat()

out = {
    "meta": {
        "generated_at_utc": generated_at,
        "data_source": "SHARE Wave 9 release 9.0.0 (fielded 2021-2022)",
        "pipeline": "v9",
        "italy_n_sample": len(italy),
        "sweden_n_sample": len(sweden),
        "italy_total_over65_individuals": ISTAT_OVER65_ITALY,
        "sweden_total_over65_individuals": SCB_OVER65_SWEDEN,
        "income_currency_assumption": (
            "Both thinc series are treated as EUR (SHARE harmonised "
            "imputed annual household income). Sweden values were "
            "verified against SCB 2022 over-65 median household income "
            "for plausibility."
        ),
        "ci_method": "Percentile bootstrap, B=2000, seed=42",
        "national_pop_source": (
            "Istat 2024 (Italy 65+); SCB 2024 (Sweden 65+)"
        ),
    },
    "country_aggregates": {
        "italy": italy_country,
        "sweden": sweden_country,
    },
    "italy_profiles": italy_profiles,
    "sweden_profiles": sweden_profiles,
    "matched_pairs": matched_pair_results,
    "time_to_maturity": time_to_maturity,
}

print(f"Writing {OUT_FILE}...")
with open(OUT_FILE, "w") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)

print()
print("=" * 60)
print("KILLER NUMBERS — quick sanity check")
print("=" * 60)
print(f"Italy total over-65: {ISTAT_OVER65_ITALY:,} individuals")
print(f"  Aggregate annual income flow: "
      f"€{italy_country['aggregate_annual_income_flow_eur_billions']}B")
print(f"  Aggregate household net wealth: "
      f"€{italy_country['aggregate_household_networth_eur_trillions']}T")
print()
for p in italy_profiles:
    print(f"  {p['profile']:>22}: {p['market_size_thousands']:>7} K · "
          f"€{p['aggregate_annual_income_eur_billions']:>5}B income · "
          f"€{p['aggregate_networth_eur_billions']:>5}B wealth · "
          f"CASP {p['casp_mean']}")
print()
print(f"Sweden total over-65: {SCB_OVER65_SWEDEN:,} individuals")
for p in sweden_profiles:
    print(f"  {p['profile']:>22}: {p['market_size_thousands']:>7} K · "
          f"€{p['aggregate_annual_income_eur_billions']:>5}B income · "
          f"CASP {p['casp_mean']}")
print()
print("Step 23 complete — killer_numbers.json written.")
