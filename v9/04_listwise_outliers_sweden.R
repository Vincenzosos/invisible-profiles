# ==============================================================================
# STEP 4: LISTWISE DELETION + OUTLIER REMOVAL — SWEDEN
# Thesis: "Beyond the Monolith"
# SHARE Wave 9, Swedish 65+
#
# Identico a Step 2 ma per Svezia.
#
# INPUT:  v9/step3_sweden_assembled.rds
# OUTPUT: v9/step4_sweden_clean.rds, v9/step4_sweden_std.rds
# ==============================================================================

library(dplyr)

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"

cat("============================================================\n")
cat("STEP 4: LISTWISE DELETION + OUTLIER REMOVAL — SWEDEN\n")
cat("============================================================\n\n")


# --- 1. LOAD ----------------------------------------------------------------

sweden <- readRDS(file.path(data_path, "v9", "outputs", "step3_sweden_assembled.rds"))
cat("  Loaded step3_sweden_assembled.rds:", nrow(sweden), "rows x", ncol(sweden), "cols\n\n")

health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")

all_31 <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

binary_vars <- c("phinact", "home_own", "internet", "ac035d1", "ac035d5",
                 "ac035d8", "sp002_", "sp008_", "ac035d4", "ac035d7",
                 "hope_future")
nonbinary_vars <- setdiff(all_31, binary_vars)

cat("  Variabili analitiche: ", length(all_31), "\n")
cat("  - Binarie (0/1):     ", length(binary_vars), "\n")
cat("  - Non-binarie:       ", length(nonbinary_vars), "\n\n")


# --- 2. LISTWISE DELETION ---------------------------------------------------

n_before <- nrow(sweden)
sweden_complete <- sweden %>% filter(complete.cases(across(all_of(all_31))))
n_after <- nrow(sweden_complete)
n_dropped <- n_before - n_after

cat("--- Listwise deletion ---\n")
cat("  Prima:  ", n_before, "righe\n")
cat("  Dopo:   ", n_after, "righe\n")
cat("  Escluse:", n_dropped, sprintf("(%.1f%%)\n\n", 100 * n_dropped / n_before))

cat("  Dettaglio missing (nelle righe eliminate):\n")
dropped_rows <- sweden %>% filter(!complete.cases(across(all_of(all_31))))
for (v in all_31) {
  n_na <- sum(is.na(dropped_rows[[v]]))
  if (n_na > 0) {
    cat(sprintf("    %-22s: %d NAs\n", v, n_na))
  }
}


# --- 3. RANK TRANSFORMATION -------------------------------------------------

cat("\n--- Rank transformation (20 variabili non-binarie) ---\n")

sweden_ranked <- sweden_complete
for (v in nonbinary_vars) {
  sweden_ranked[[v]] <- rank(sweden_ranked[[v]], ties.method = "average")
}

cat("  Esempio range dopo rank:\n")
for (v in nonbinary_vars[1:5]) {
  r <- range(sweden_ranked[[v]])
  cat(sprintf("    %-22s: [%.1f, %.1f]\n", v, r[1], r[2]))
}
cat("    ...\n")


# --- 4. STANDARDIZZAZIONE ---------------------------------------------------

cat("\n--- Standardizzazione (z-score, tutte 31 variabili) ---\n")

sweden_std <- sweden_ranked
for (v in all_31) {
  sweden_std[[v]] <- as.numeric(scale(sweden_std[[v]]))
}

cat("  Media e SD dopo standardizzazione (primi 5):\n")
for (v in all_31[1:5]) {
  cat(sprintf("    %-22s: mean=%.4f, sd=%.4f\n", v,
              mean(sweden_std[[v]]), sd(sweden_std[[v]])))
}
cat("    ... (tutte dovrebbero avere mean≈0, sd≈1)\n")


# --- 5. OUTLIER DETECTION (MAHALANOBIS) --------------------------------------

cat("\n--- Outlier detection (Mahalanobis distance) ---\n")

# CHECK: variabili a varianza zero (es. ac035d4, ac035d7 se nessuno partecipa)
# Queste causano singolarità nella matrice di covarianza.
# Se presenti, le escludiamo temporaneamente dal calcolo Mahalanobis.
zero_var <- sapply(sweden_std[, all_31], function(x) sd(x) == 0 | is.na(sd(x)))
if (any(zero_var)) {
  cat("  ATTENZIONE: variabili a varianza zero escluse dal Mahalanobis:\n")
  cat("   ", paste(names(zero_var)[zero_var], collapse = ", "), "\n")
  mahal_vars <- all_31[!zero_var]
} else {
  mahal_vars <- all_31
}

X <- as.matrix(sweden_std[, mahal_vars])
center <- colMeans(X)
cov_mat <- cov(X)

# Verifica che la matrice di covarianza sia invertibile
if (rcond(cov_mat) < .Machine$double.eps) {
  cat("  ATTENZIONE: matrice di covarianza quasi singolare.\n")
  cat("  Usando pseudo-inversa (MASS::ginv) per Mahalanobis.\n")
  library(MASS)
  cov_inv <- ginv(cov_mat)
  mah_dist <- apply(X, 1, function(x) {
    d <- x - center
    as.numeric(t(d) %*% cov_inv %*% d)
  })
} else {
  mah_dist <- mahalanobis(X, center = center, cov = cov_mat)
}

sweden_std$mahal_dist <- mah_dist

df <- length(mahal_vars)
cutoff <- qchisq(0.999, df = df)
cat("  Cutoff chi-squared (df=", df, ", p=0.001):", round(cutoff, 2), "\n")

is_outlier <- mah_dist > cutoff
n_outliers <- sum(is_outlier)
cat("  Outlier identificati:", n_outliers, sprintf("(%.1f%%)\n", 100 * n_outliers / nrow(sweden_std)))

cat("  Distribuzione distanze di Mahalanobis:\n")
cat("    Min:   ", round(min(mah_dist), 2), "\n")
cat("    Q1:    ", round(quantile(mah_dist, 0.25), 2), "\n")
cat("    Median:", round(median(mah_dist), 2), "\n")
cat("    Q3:    ", round(quantile(mah_dist, 0.75), 2), "\n")
cat("    Max:   ", round(max(mah_dist), 2), "\n")
cat("    Cutoff:", round(cutoff, 2), "\n")


# --- 6. RIMOZIONE OUTLIER ---------------------------------------------------

sweden_clean <- sweden_std %>% filter(!is_outlier)
n_final <- nrow(sweden_clean)

cat("\n--- Rimozione outlier ---\n")
cat("  Prima di Mahalanobis:", nrow(sweden_std), "\n")
cat("  Outlier rimossi:     ", n_outliers, "\n")
cat("  Dataset finale:      ", n_final, "righe\n\n")


# --- 7. RIEPILOGO PIPELINE --------------------------------------------------

cat("============================================================\n")
cat("RIEPILOGO PIPELINE — SWEDEN\n")
cat("============================================================\n")
cat("  Step 3 - Assemblato:        ", n_before, "righe\n")
cat("  Step 4a - Listwise deletion: ", n_after, sprintf("righe (-%d, -%.1f%%)\n",
    n_dropped, 100 * n_dropped / n_before))
cat("  Step 4b - Outlier removal:   ", n_final, sprintf("righe (-%d, -%.1f%%)\n",
    n_outliers, 100 * n_outliers / n_after))
cat("  DATASET FINALE SWEDEN:       ", n_final, "righe x 31 variabili\n")
cat("============================================================\n")

# Confronto con Italia
it_file <- file.path(data_path, "v9", "outputs", "step2_italy_clean.rds")
if (file.exists(it_file)) {
  it <- readRDS(it_file)
  cat("\n  Italia finale: ", nrow(it), "righe\n")
  cat("  Svezia finale: ", n_final, "righe\n")
  cat("  Rapporto IT/SE:", round(nrow(it) / n_final, 2), "\n")
}


# --- 8. SALVA ----------------------------------------------------------------

sweden_clean_original <- sweden_complete %>% filter(!is_outlier)
sweden_clean_std <- sweden_clean %>% select(-mahal_dist)

saveRDS(sweden_clean_original, file.path(data_path, "v9", "outputs", "step4_sweden_clean.rds"))
saveRDS(sweden_clean_std,      file.path(data_path, "v9", "outputs", "step4_sweden_std.rds"))

cat("\n  Salvato: v9/step4_sweden_clean.rds     (valori originali)\n")
cat("  Salvato: v9/step4_sweden_std.rds       (standardizzati)\n")

# Preview descrittiva
cat("\n--- Preview variabili (valori originali, post-cleaning) ---\n")
cat("Variabile              |   Mean |     SD |    Min |    Max\n")
cat("-----------------------------------------------------------\n")
for (v in all_31) {
  vals <- sweden_clean_original[[v]]
  cat(sprintf("%-22s | %6.2f | %6.2f | %6.2f | %6.2f\n",
              v, mean(vals), sd(vals), min(vals), max(vals)))
}

cat("\n============================================================\n")
cat("STEP 4 COMPLETATO.\n")
cat("Prossimo step: PCA + Factor Analysis (Step 5)\n")
cat("============================================================\n")
