# ==============================================================================
# STEP 46: ISOLATION PARADOX — covariate-adjusted regression (Table 4.2)
# Thesis: "Invisible Profiles"
#
# Purpose: reproduce the regression-ADJUSTED Moderate Isolated vs Traditional
# Social healthcare gaps reported in Chapter 4 Table 4.2 (tab:ch4-isolation-
# regression). The descriptive (unadjusted) gaps already reproduce from
# killer_numbers.json (MI specialist 1.08 / TS 2.02; MI dental 21.0% / TS 47.8%).
# This script estimates the adjusted models so the headline -0.669 specialist /
# -27.9 pp dental figures have a committed, reproducible source.
#
# Control set (per thesis): age, chronic conditions, self-rated health (sphus),
# household income (log_thinc), gender (female), depressive symptoms (eurod).
# Models: OLS for count outcomes; linear probability model (LPM) for binary
# dental, so the coefficient is a percentage-point gap (x100).
# Estimation restricted to the MI + TS subsample, MI indicator (TS = reference).
#
# INPUT:  v9/outputs/step7_italy_with_clusters.rds
#         _share_data/sharew9_rel9-0-0_hc.dta
# OUTPUT: v9/outputs/step46_isolation_regression.csv
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
})

data_path <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"

recode_share        <- function(x) ifelse(x < 0, NA, x)
recode_binary_share <- function(x) { x <- recode_share(x); ifelse(x == 1, 1, ifelse(x == 5, 0, NA)) }

# ---- Healthcare extraction (identical recodes to 11_healthcare.R) ----
hc_file <- file.path(data_path, "_share_data", "sharew9_rel9-0-0_hc.dta")
hc <- read_dta(hc_file, col_select = c("mergeid", "country", "hc010_", "hc602_",
                                       "hc876_", "hc877_",
                                       "hc841d1","hc841d2","hc841d3","hc841d4",
                                       "hc841d5","hc841d6","hc841d7")) %>%
  mutate(
    dentist_12m   = recode_binary_share(hc010_),
    doctor_visits = recode_share(hc602_),
    gp_contacts   = recode_share(hc876_),
    spec_contacts = recode_share(hc877_),
    forgone_gp = recode_binary_share(hc841d1), forgone_spec = recode_binary_share(hc841d2),
    forgone_drugs = recode_binary_share(hc841d3), forgone_dental = recode_binary_share(hc841d4),
    forgone_optical = recode_binary_share(hc841d5), forgone_home = recode_binary_share(hc841d6),
    forgone_paidhome = recode_binary_share(hc841d7)
  ) %>%
  rowwise() %>%
  mutate(forgone_any_cost = as.integer(any(c(forgone_gp, forgone_spec, forgone_drugs,
                                             forgone_dental, forgone_optical, forgone_home,
                                             forgone_paidhome) == 1, na.rm = TRUE))) %>%
  ungroup() %>%
  dplyr::select(mergeid, country, dentist_12m, doctor_visits, gp_contacts,
                spec_contacts, forgone_any_cost)

# ---- Merge with deployed Italian clusters, restrict to MI + TS ----
italy <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
df <- italy %>%
  left_join(hc %>% filter(country == 16), by = "mergeid") %>%
  filter(profile %in% c("Moderate Isolated", "Traditional Social")) %>%
  mutate(mi     = as.integer(profile == "Moderate Isolated"),  # TS = reference
         female = as.integer(gender == 2))

covars <- c("age", "chronic", "sphus", "log_thinc", "female", "eurod")
stopifnot(all(c("spec_contacts","dentist_12m", covars) %in% names(df)))

# ---- SELF-CHECK: descriptive means must match killer_numbers.json ----
cat("=== SELF-CHECK (descriptive, must match killer_numbers.json) ===\n")
chk <- df %>% group_by(profile) %>%
  summarise(spec = mean(spec_contacts, na.rm = TRUE),
            dental_pct = 100 * mean(dentist_12m, na.rm = TRUE), n = n(), .groups = "drop")
print(chk)
cat("Expected: Moderate Isolated spec~1.08 dental~21.0% | Traditional Social spec~2.02 dental~47.8%\n\n")

# ---- Adjusted models ----
fit_gap <- function(outcome, binary = FALSE) {
  f  <- as.formula(paste(outcome, "~ mi +", paste(covars, collapse = " + ")))
  d  <- df[stats::complete.cases(df[, c(outcome, "mi", covars)]), ]
  m  <- lm(f, data = d)
  ci <- confint(m)["mi", ]
  s  <- summary(m)$coefficients["mi", ]
  mult <- if (binary) 100 else 1   # LPM -> percentage points
  data.frame(outcome = outcome,
             adj_gap = unname(s["Estimate"]) * mult,
             se      = unname(s["Std. Error"]) * mult,
             ci_low  = ci[1] * mult, ci_high = ci[2] * mult,
             p       = unname(s["Pr(>|t|)"]), n = nrow(d))
}

res <- bind_rows(
  fit_gap("spec_contacts"),
  fit_gap("dentist_12m", binary = TRUE),
  fit_gap("doctor_visits"),
  fit_gap("gp_contacts"),
  fit_gap("forgone_any_cost", binary = TRUE)
)
cat("=== ADJUSTED MI - TS gaps (controls: ", paste(covars, collapse = ", "), ") ===\n", sep = "")
print(res, row.names = FALSE)
cat("\nThesis Table 4.2 headline: specialist adj_gap ~ -0.669 (p<.001) ; dentist_12m adj_gap ~ -27.9 pp (p<.001)\n")

out <- file.path(data_path, "v9", "outputs", "step46_isolation_regression.csv")
write.csv(res, out, row.names = FALSE)
cat("\nWrote", out, "\n")
