# ==============================================================================
# STEP 23: KILLER NUMBERS FOR THE SILVER ECONOMY INTELLIGENCE PRODUCT
# Thesis: "Invisible Profiles" - Bocconi MSc EMIT (course 20570, Prof. Trentini)
#
# v2 (2026-04-28): Replaced ad-hoc €-per-uptake assumptions with low/central/
# high ranges sourced from public Italian and European authorities (GIMBE,
# ANIA, ANDI, AIFA OsMed, Banca d'Italia, AIPB, Eurostat, Censis, Quotalo
# market review, etc.). All sources are documented in
# webapp/src/data/sources.json.
#
# Reads step11_italy_with_healthcare.rds and step11_sweden_with_healthcare.rds
# (individual-level data with cluster assignments + healthcare merge) and
# computes the per-profile and per-country aggregates that drive the B2B
# product:
#
#   - Per-profile market sizing (n in sample, % of sample, projected n in
#     national population using Istat/SCB total over-65, aggregate income
#     and aggregate household net worth in EUR)
#   - Per-profile economic + behavioural snapshot with bootstrap 95% CI
#   - Italy <-> Sweden matched-pair gaps with opportunity sizing as
#     [low, central, high] ranges driven by sourced ranges of €-per-uptake
#     for the dimensions where uptake monetisation is defensible
#   - Italy total addressable silver economy aggregates
#   - Time-to-maturity estimates using post-pandemic Eurostat trend
#
# OUTPUT: v9/outputs/killer_numbers.json
# Documented sources: webapp/src/data/sources.json
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

# ---- Sourced €-per-uptake ranges -------------------------------------------
# Each range: (low, central, high) EUR per individual per year, with the
# source identifier from webapp/src/data/sources.json.
#
# DENTAL: low end = basic prevention-only product (€100-200/y); central =
#   typical individual senior dental insurance (€300-400/y); high = senior
#   comprehensive with implants/orthodontics (€500-800/y). Sources:
#   private_dental_premiums (market review of Italian individual dental
#   policies for over-65); andi_2024 (€8.5B total dental private spending);
#   gimbe_2025 (~30% of OOP healthcare on dental).
#
# SPECIALIST: low = single specialist visit out-of-pocket (€100/y if 1
#   visit/y); central = 2 visits/y at €150 each (€300/y); high = bundle of
#   3-4 elective specialist visits + one diagnostic test (€500/y).
#   Source: private_specialist_2024 (Censis 2024, market reviewers).
#
# OTC/PHARMA: low = OTC adjacency only (€60/y); central = OTC + adherence
#   (€100/y); high = OTC + chronic adherence + telehealth subscription
#   (€180/y). Source: aifa_osmed_2024.

DENTAL_PREMIUM_EUR = {"low": 150, "central": 300, "high": 500,
                      "sources": ["private_dental_premiums", "andi_2024",
                                  "gimbe_2025"]}
SPECIALIST_PREMIUM_EUR = {"low": 100, "central": 250, "high": 450,
                          "sources": ["private_specialist_2024"]}
OTC_PREMIUM_EUR = {"low": 60, "central": 100, "high": 180,
                   "sources": ["aifa_osmed_2024"]}

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
        "internet_pct": round_pct(sub["internet"].mean(), 4),
        "online_banking_health_proxy_pct": round_pct(
            sub[["ac035d1", "ac035d5", "ac035d8"]].max(axis=1).mean(), 4
        ),
        "social_network_size_mean": round(float(sub["sn_size_w9"].mean()), 2),
        "loneliness_mean": round(loneliness_mean, 2),
        "fluency_mean": round(fluency_mean, 2),
        "casp_mean": round(casp_mean, 2),
        "casp_mean_ci": [round(casp_lo, 2), round(casp_hi, 2)],
        "lifesat_mean": round(lifesat_mean, 2),
        "hope_future_pct": round_pct(sub["hope_future"].mean(), 4),
        "eurod_mean": round(eurod_mean, 2),
        "dentist_12m_pct": round_pct(sub["dentist_12m"].mean(), 4),
        "doctor_visits_mean": round(float(sub["doctor_visits"].mean()), 2),
        "gp_contacts_mean": round(float(sub["gp_contacts"].mean()), 2),
        "specialist_contacts_mean": round(
            float(sub["spec_contacts"].mean()), 2),
        "forgone_care_for_cost_pct": round_pct(
            sub["forgone_any_cost"].mean(), 4),
        "hospitalised_pct": round_pct(sub["hospitalised"].mean(), 4),
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


# ---- Matched-pair gap with sourced opportunity ranges ----------------------

GAP_DIMENSIONS = [
    # (key, var, scale_text, business_meaning, premium_dict)
    ("dentist_12m",     "dentist_12m",     "binary 0/1",
     "preventive dental insurance market headroom",
     DENTAL_PREMIUM_EUR),
    ("internet",        "internet",        "binary 0/1",
     "digital reach / online services market headroom",
     None),
    ("forgone_cost",    "forgone_any_cost","binary 0/1",
     "affordability gap (negative -> Sweden has less unmet need)",
     None),
    ("specialist",      "spec_contacts",   "count 12m",
     "private specialist consultation market headroom",
     SPECIALIST_PREMIUM_EUR),
    ("casp",            "casp",            "12-48",
     "subjective wellbeing market headroom",
     None),
    ("internet_banking","ac035d5",         "binary 0/1",
     "digital financial services market headroom",
     None),
    ("online_purchase", "ac035d1",         "binary 0/1",
     "e-commerce silver market headroom",
     None),
]

def matched_pair_gap(label, italian_profile, swedish_profile):
    sub_it = italy[italy["profile"] == italian_profile]
    sub_se = sweden[sweden["profile"] == swedish_profile]

    italian_market_size = int(round(
        len(sub_it) / len(italy) * ISTAT_OVER65_ITALY))

    dimensions_out = []
    for key, var, scale, meaning, premium in GAP_DIMENSIONS:
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
        if premium is not None and scale.startswith("binary"):
            gap = max(0.0, gap_point)
            out["opportunity_size_eur"] = {
                "low": round_money(gap * italian_market_size * premium["low"], -3),
                "central": round_money(gap * italian_market_size * premium["central"], -3),
                "high": round_money(gap * italian_market_size * premium["high"], -3),
            }
            out["opportunity_size_eur_millions"] = {
                "low": round(gap * italian_market_size * premium["low"] / 1e6, 1),
                "central": round(gap * italian_market_size * premium["central"] / 1e6, 1),
                "high": round(gap * italian_market_size * premium["high"] / 1e6, 1),
            }
            out["premium_assumption_eur"] = {
                "low": premium["low"],
                "central": premium["central"],
                "high": premium["high"],
                "unit": "EUR per individual per year if Italian segment closes the gap with Sweden",
                "sources": premium["sources"],
            }
        dimensions_out.append(out)

    return {
        "matched_pair_label": label,
        "italian_profile": italian_profile,
        "swedish_profile": swedish_profile,
        "italian_market_size_individuals": italian_market_size,
        "italian_market_size_thousands": round(italian_market_size / 1e3, 1),
        "dimensions": dimensions_out,
    }

print("Computing matched-pair gaps with sourced ranges...")
matched_pair_results = [
    matched_pair_gap(label, it_p, se_p)
    for label, it_p, se_p in MATCHED_PAIRS
]


# ---- Time-to-maturity calibrated against Eurostat 2018-2024 ----------------
# Italy 65-74 internet use (Eurostat ICT individuals, ISTAT Cittadini e ICT):
# 2023: 60.4% -> 2024: 65.6%; trend post-pandemic +5.2pp/year.
# Pre-pandemic 2018-2022 trend was closer to +2 to +3 pp/year.
# Sweden 65-74 internet use ~87% in recent years.
# Conservative central assumption: 3 pp/year (blend of pre- and post-pandemic).

CONSERVATIVE_RATE = 1.0   # pessimistic
CENTRAL_RATE = 3.0         # blended Italy 65-74 trajectory
RECENT_RATE = 5.2          # post-pandemic 2023->2024

def time_to_maturity(italy_pct, sweden_pct):
    if italy_pct is None or sweden_pct is None:
        return None
    gap_pp = (sweden_pct - italy_pct) * 100
    if gap_pp <= 0:
        return {"low": 0, "central": 0, "high": 0}
    return {
        "low": round(gap_pp / RECENT_RATE, 1),
        "central": round(gap_pp / CENTRAL_RATE, 1),
        "high": round(gap_pp / CONSERVATIVE_RATE, 1),
    }


time_to_maturity_block = {
    "method": "Linear extrapolation calibrated against Eurostat ICT-individuals "
              "Italy 65-74 cohort 2018-2024. Three rate scenarios used.",
    "rate_scenarios_pp_per_year": {
        "conservative": CONSERVATIVE_RATE,
        "central": CENTRAL_RATE,
        "recent_post_pandemic": RECENT_RATE,
    },
    "italy_2024_internet_65_74_pct_eurostat": 65.6,
    "italy_2023_internet_65_74_pct_eurostat": 60.4,
    "sweden_recent_internet_65_74_pct_estimate": 87.0,
    "sources": ["eurostat_ict_2024", "istat_ict_2024"],
    "estimates_years_to_close": {
        "internet_overall": time_to_maturity(
            italy_country["internet_penetration_pct"],
            sweden_country["internet_penetration_pct"]),
        "dentist_overall": time_to_maturity(
            italy_country["dentist_12m_pct"],
            sweden_country["dentist_12m_pct"]),
    },
}


# ---- Assemble final JSON ---------------------------------------------------

generated_at = pd.Timestamp.utcnow().isoformat()

out = {
    "meta": {
        "generated_at_utc": generated_at,
        "schema_version": "v2",
        "data_source": "SHARE Wave 9 release 9.0.0 (fielded 2021-2022)",
        "pipeline": "v9",
        "italy_n_sample": len(italy),
        "sweden_n_sample": len(sweden),
        "italy_total_over65_individuals": ISTAT_OVER65_ITALY,
        "sweden_total_over65_individuals": SCB_OVER65_SWEDEN,
        "income_currency_assumption": (
            "Both thinc series are treated as EUR (SHARE harmonised "
            "imputed annual household income). Sweden values verified "
            "against SCB 2022 over-65 median household income for "
            "plausibility."
        ),
        "ci_method": "Percentile bootstrap, B=2000, seed=42",
        "national_pop_sources": ["istat_2024", "scb_2024"],
        "opportunity_sizing_sources": [
            "private_dental_premiums",
            "private_specialist_2024",
            "andi_2024",
            "gimbe_2025",
        ],
        "sources_bibliography_path": "webapp/src/data/sources.json",
    },
    "country_aggregates": {
        "italy": italy_country,
        "sweden": sweden_country,
    },
    "italy_profiles": italy_profiles,
    "sweden_profiles": sweden_profiles,
    "matched_pairs": matched_pair_results,
    "time_to_maturity": time_to_maturity_block,
    "premium_assumptions": {
        "dental_eur_per_individual_per_year": DENTAL_PREMIUM_EUR,
        "specialist_eur_per_individual_per_year": SPECIALIST_PREMIUM_EUR,
        "otc_pharma_eur_per_individual_per_year": OTC_PREMIUM_EUR,
    },
}

print(f"Writing {OUT_FILE}...")
with open(OUT_FILE, "w") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)

print()
print("=" * 72)
print("KILLER NUMBERS v2 — sourced ranges + sensitivity")
print("=" * 72)
print(f"Italy total over-65: {ISTAT_OVER65_ITALY:,} individuals")
print(f"  Aggregate annual income flow: "
      f"€{italy_country['aggregate_annual_income_flow_eur_billions']}B")
print(f"  Aggregate household net wealth: "
      f"€{italy_country['aggregate_household_networth_eur_trillions']}T")
print()
print("Premium ranges (EUR per individual per year):")
print(f"  Dental:     €{DENTAL_PREMIUM_EUR['low']:>3} / €{DENTAL_PREMIUM_EUR['central']:>3} / €{DENTAL_PREMIUM_EUR['high']:>3}  (low/central/high)")
print(f"  Specialist: €{SPECIALIST_PREMIUM_EUR['low']:>3} / €{SPECIALIST_PREMIUM_EUR['central']:>3} / €{SPECIALIST_PREMIUM_EUR['high']:>3}")
print(f"  OTC pharma: €{OTC_PREMIUM_EUR['low']:>3} / €{OTC_PREMIUM_EUR['central']:>3} / €{OTC_PREMIUM_EUR['high']:>3}")
print()
print("Time-to-maturity (years to close internet penetration gap to Sweden):")
ttm = time_to_maturity_block["estimates_years_to_close"]["internet_overall"]
if ttm is not None:
    print(f"  conservative (1pp/y): {ttm['high']} years")
    print(f"  central (3pp/y):       {ttm['central']} years")
    print(f"  post-pandemic (5pp/y): {ttm['low']} years")
print()
print("Step 23 v2 complete.")
