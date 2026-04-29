# ==============================================================================
# STEP 2: LISTWISE DELETION + OUTLIER REMOVAL
# Thesis: "Beyond the Monolith"
# SHARE Wave 9, Italian 65+
#
# Questo script:
#   1. Carica il dataset assemblato da Step 1
#   2. Applica listwise deletion sulle 31 variabili analitiche
#   3. Rank-trasforma le 20 variabili non-binarie
#   4. Standardizza tutte le 31 variabili
#   5. Calcola distanza di Mahalanobis per outlier detection
#   6. Rimuove outlier (chi-squared, p < 0.001)
#   7. Salva dataset pulito (pronto per PCA/FA/Clustering)
#
# INPUT:  v9/step1_italy_w8_assembled.rds
# OUTPUT: v9/step2_italy_w8_clean.rds
# ==============================================================================

# --- 0. SETUP ---------------------------------------------------------------

library(dplyr)

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"

cat("============================================================\n")
cat("STEP 2: LISTWISE DELETION + OUTLIER REMOVAL — ITALY\n")
cat("============================================================\n\n")


# --- 1. LOAD STEP 1 OUTPUT --------------------------------------------------

italy <- readRDS(file.path(data_path, "v9", "outputs", "step1_italy_w8_assembled.rds"))
cat("  Loaded step1_italy_w8_assembled.rds:", nrow(italy), "rows x", ncol(italy), "cols\n\n")

# Definizione delle 31 variabili analitiche (stesso ordine di Step 1)
health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")

all_31 <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

# Le 11 variabili binarie (0/1) — NON rank-trasformate, solo standardizzate
binary_vars <- c("phinact", "home_own", "internet", "ac035d1", "ac035d5",
                 "ac035d8", "sp002_", "sp008_", "ac035d4", "ac035d7",
                 "hope_future")

# Le 20 variabili non-binarie — verranno rank-trasformate
nonbinary_vars <- setdiff(all_31, binary_vars)

cat("  Variabili analitiche: ", length(all_31), "\n")
cat("  - Binarie (0/1):     ", length(binary_vars), "\n")
cat("  - Non-binarie:       ", length(nonbinary_vars), "\n\n")


# --- 2. LISTWISE DELETION ---------------------------------------------------
# Rimuovi tutte le righe con almeno un NA nelle 31 variabili analitiche.

n_before <- nrow(italy)
italy_complete <- italy %>% filter(complete.cases(across(all_of(all_31))))
n_after <- nrow(italy_complete)
n_dropped <- n_before - n_after

cat("--- Listwise deletion ---\n")
cat("  Prima:  ", n_before, "righe\n")
cat("  Dopo:   ", n_after, "righe\n")
cat("  Escluse:", n_dropped, sprintf("(%.1f%%)\n\n", 100 * n_dropped / n_before))

# Dettaglio: quanti NA per variabile (tra quelli eliminati)
cat("  Dettaglio missing (nelle righe eliminate):\n")
dropped_rows <- italy %>% filter(!complete.cases(across(all_of(all_31))))
for (v in all_31) {
  n_na <- sum(is.na(dropped_rows[[v]]))
  if (n_na > 0) {
    cat(sprintf("    %-22s: %d NAs\n", v, n_na))
  }
}


# --- 3. RANK TRANSFORMATION -------------------------------------------------
# Per le 20 variabili non-binarie, applichiamo rank transformation.
# rank() con ties.method = "average": i valori vengono sostituiti con il loro
# rango nella distribuzione. Questo rende le variabili comparabili tra loro
# e riduce l'influenza di outlier e distribuzioni skewed.
# Le 11 binarie restano come 0/1.

cat("\n--- Rank transformation (20 variabili non-binarie) ---\n")

italy_ranked <- italy_complete
for (v in nonbinary_vars) {
  italy_ranked[[v]] <- rank(italy_ranked[[v]], ties.method = "average")
}

# Verifica: range dei ranghi
cat("  Esempio range dopo rank:\n")
for (v in nonbinary_vars[1:5]) {
  r <- range(italy_ranked[[v]])
  cat(sprintf("    %-22s: [%.1f, %.1f]\n", v, r[1], r[2]))
}
cat("    ...\n")


# --- 4. STANDARDIZZAZIONE ---------------------------------------------------
# Standardizza TUTTE le 31 variabili (rank-trasformate e binarie) a media 0, SD 1.
# Questa è la base per il clustering (Trentini: cluster su variabili standardizzate).

cat("\n--- Standardizzazione (z-score, tutte 31 variabili) ---\n")

italy_std <- italy_ranked
for (v in all_31) {
  italy_std[[v]] <- as.numeric(scale(italy_std[[v]]))
}

# Verifica
cat("  Media e SD dopo standardizzazione (primi 5):\n")
for (v in all_31[1:5]) {
  cat(sprintf("    %-22s: mean=%.4f, sd=%.4f\n", v,
              mean(italy_std[[v]]), sd(italy_std[[v]])))
}
cat("    ... (tutte dovrebbero avere mean≈0, sd≈1)\n")


# --- 5. OUTLIER DETECTION (MAHALANOBIS) --------------------------------------
# Distanza di Mahalanobis: misura quanto un'osservazione è distante dal centroide
# multivariato, tenendo conto delle correlazioni tra variabili.
# Cutoff: chi-squared con df = numero di variabili, p < 0.001
#
# NOTA: calcoliamo Mahalanobis sulle variabili STANDARDIZZATE (post-rank per
# le non-binarie). Questo è coerente con l'approccio del dataset precedente.

cat("\n--- Outlier detection (Mahalanobis distance) ---\n")

# Matrice delle 31 variabili standardizzate
X <- as.matrix(italy_std[, all_31])

# Centroide e matrice di covarianza
center <- colMeans(X)
cov_mat <- cov(X)

# Calcolo distanza di Mahalanobis
mah_dist <- mahalanobis(X, center = center, cov = cov_mat)
italy_std$mahal_dist <- mah_dist

# Cutoff: chi-squared(df = 31, p = 0.001)
df <- length(all_31)
cutoff <- qchisq(0.999, df = df)
cat("  Cutoff chi-squared (df=", df, ", p=0.001):", round(cutoff, 2), "\n")

# Identifica outlier
is_outlier <- mah_dist > cutoff
n_outliers <- sum(is_outlier)
cat("  Outlier identificati:", n_outliers, sprintf("(%.1f%%)\n", 100 * n_outliers / nrow(italy_std)))

# Distribuzione distanze
cat("  Distribuzione distanze di Mahalanobis:\n")
cat("    Min:   ", round(min(mah_dist), 2), "\n")
cat("    Q1:    ", round(quantile(mah_dist, 0.25), 2), "\n")
cat("    Median:", round(median(mah_dist), 2), "\n")
cat("    Q3:    ", round(quantile(mah_dist, 0.75), 2), "\n")
cat("    Max:   ", round(max(mah_dist), 2), "\n")
cat("    Cutoff:", round(cutoff, 2), "\n")


# --- 6. RIMOZIONE OUTLIER ---------------------------------------------------

italy_clean <- italy_std %>% filter(!is_outlier)
n_final <- nrow(italy_clean)

cat("\n--- Rimozione outlier ---\n")
cat("  Prima di Mahalanobis:", nrow(italy_std), "\n")
cat("  Outlier rimossi:     ", n_outliers, "\n")
cat("  Dataset finale:      ", n_final, "righe\n\n")


# --- 7. RIEPILOGO PIPELINE --------------------------------------------------

cat("============================================================\n")
cat("RIEPILOGO PIPELINE\n")
cat("============================================================\n")
cat("  Step 1 - Assemblato:        ", n_before, "righe\n")
cat("  Step 2a - Listwise deletion: ", n_after, sprintf("righe (-%d, -%.1f%%)\n",
    n_dropped, 100 * n_dropped / n_before))
cat("  Step 2b - Outlier removal:   ", n_final, sprintf("righe (-%d, -%.1f%%)\n",
    n_outliers, 100 * n_outliers / n_after))
cat("  DATASET FINALE:              ", n_final, "righe x 31 variabili\n")
cat("============================================================\n")

# Confronto con dataset precedente
old_file <- file.path(data_path, "share_italy_extended.rds")
if (file.exists(old_file)) {
  old <- readRDS(old_file)
  cat("\n  Riferimento dataset precedente:", nrow(old), "righe\n")
  cat("  Differenza:", n_final - nrow(old), "righe\n")
}


# --- 8. SALVA ----------------------------------------------------------------

# Salva il dataset con:
#   - Variabili originali (pre-rank, pre-standardizzazione) per descrittiva
#   - Variabili standardizzate per clustering
#   - Mahalanobis distance per documentazione

# Dataset pulito con valori ORIGINALI (per tabelle descrittive)
italy_clean_original <- italy_complete %>% filter(!is_outlier)

# Dataset pulito con valori STANDARDIZZATI (per clustering)
italy_clean_std <- italy_clean %>% select(-mahal_dist)

# Salva entrambi
saveRDS(italy_clean_original, file.path(data_path, "v9", "outputs", "step2_italy_w8_clean.rds"))
saveRDS(italy_clean_std,      file.path(data_path, "v9", "outputs", "step2_italy_w8_std.rds"))

cat("\n  Salvato: v9/step2_italy_w8_clean.rds     (valori originali, per descrittiva)\n")
cat("  Salvato: v9/step2_italy_w8_std.rds       (standardizzati, per clustering)\n")

# Preview descrittiva rapida
cat("\n--- Preview variabili (valori originali, post-cleaning) ---\n")
cat("Variabile              |   Mean |     SD |    Min |    Max\n")
cat("-----------------------------------------------------------\n")
for (v in all_31) {
  vals <- italy_clean_original[[v]]
  cat(sprintf("%-22s | %6.2f | %6.2f | %6.2f | %6.2f\n",
              v, mean(vals), sd(vals), min(vals), max(vals)))
}

cat("\n============================================================\n")
cat("STEP 2 COMPLETATO.\n")
cat("Prossimo step: descrittive + data assembly Sweden (Step 3)\n")
cat("============================================================\n")
