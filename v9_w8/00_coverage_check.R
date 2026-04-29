# ============================================================
# 00_coverage_check.R
# Verifica copertura delle NUOVE variabili candidate
# (Big Five + trust + risk aversion + planning horizon)
# sul campione over-65 IT e SE della SHARE Wave 9
# ============================================================

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
})

data_path <- "/Users/vincenzosilvestri/Desktop/SHARE DATASET/DATASET RESEARCH/"

# --- 1. Load coverscreen (per country + age) ---
cv <- read_dta(paste0(data_path, "sharew8_rel9-0-0_cv_r.dta"))
cat("Coverscreen rows:", nrow(cv), "\n")
cat("Country var present:", "country" %in% names(cv), "\n")
cat("Age var candidates:", grep("age", names(cv), value = TRUE, ignore.case = TRUE), "\n\n")

# SHARE country codes: Italy = 16, Sweden = 13
# Age variable: age2022 / int_year - yrbirth — check what's there
age_candidates <- grep("^age|yrbirth", names(cv), value = TRUE, ignore.case = TRUE)
cat("Age/birth candidates in cv_r:", age_candidates, "\n\n")

# --- 2. Load Big Five ---
big5 <- read_dta(paste0(data_path, "sharew8_rel9-0-0_gv_big5.dta"))
cat("Big5 rows:", nrow(big5), "\n")
cat("Big5 vars:", paste(grep("^bfi10", names(big5), value = TRUE), collapse = ", "), "\n\n")

# --- 3. Load expectations (trust, risk aversion, planning) ---
ex <- read_dta(paste0(data_path, "sharew8_rel9-0-0_ex.dta"))
cat("Expectations rows:", nrow(ex), "\n")

# --- 4. Merge on mergeid ---
df <- cv %>%
  select(mergeid, country, any_of(c("age2022", "yrbirth", "int_year"))) %>%
  left_join(big5 %>% select(mergeid, starts_with("bfi10")), by = "mergeid") %>%
  left_join(ex %>% select(mergeid, ex026_, ex110_, ex111_, ex029_), by = "mergeid")

# Compute age (rough): if yrbirth exists, age = 2022 - yrbirth (W9 fielded mostly 2021-22)
if ("yrbirth" %in% names(df)) {
  df$age_calc <- 2022 - as.numeric(df$yrbirth)
}

# --- 5. Filter IT (country==16) and SE (country==13), over-65 ---
for (cc in c(16, 13)) {
  lbl <- ifelse(cc == 16, "ITALIA", "SVEZIA")
  sub <- df %>% filter(country == cc, age_calc >= 65)
  cat("========== ", lbl, " (country=", cc, ") ==========\n", sep = "")
  cat("N over-65:", nrow(sub), "\n\n")

  vars_check <- c(
    "bfi10_extra", "bfi10_agree", "bfi10_consc", "bfi10_neuro", "bfi10_open",
    "ex026_", "ex110_", "ex111_", "ex029_"
  )

  for (v in vars_check) {
    if (v %in% names(sub)) {
      x <- sub[[v]]
      # treat negative codes (-1..-9 standard SHARE missing) as NA
      x_clean <- ifelse(is.na(x) | x < 0, NA, x)
      n_ok <- sum(!is.na(x_clean))
      pct <- round(100 * n_ok / nrow(sub), 1)
      cat(sprintf("  %-15s  n=%4d  cov=%5.1f%%\n", v, n_ok, pct))
    } else {
      cat(sprintf("  %-15s  NOT FOUND\n", v))
    }
  }
  cat("\n")
}

cat("=== DONE ===\n")
