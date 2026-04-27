# ==============================================================================
# STEP 5: PCA + FACTOR ANALYSIS — ITALY
# Thesis: "Beyond the Monolith"
# SHARE Wave 9, Italian 65+
#
# Questo script:
#   Part A — Dimension-wise PCA (5 dimensioni separate)
#   Part B — Factor Analysis su tutte le variabili (6 fattori, varimax)
#
# NOTA: ac035d4 e ac035d7 hanno varianza zero in Italia (nessuno ha partecipato
# a corsi educativi o organizzazioni politiche). Vengono escluse da PCA e FA.
# Le variabili analitiche effettive per PCA/FA sono 29 (31 - 2).
#
# INPUT:  v9/step2_italy_std.rds   (standardizzate, per PCA/FA)
#         v9/step2_italy_clean.rds  (valori originali, per descrittiva)
# OUTPUT: v9/step5_italy_pca_results.rds
#         v9/step5_italy_fa_results.rds
# ==============================================================================

library(dplyr)
library(psych)       # fa(), parallel(), KMO()
library(ggplot2)

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"

# Self-contained pipeline: tutta la PCA/FA qui sotto usa psych::fa e base R,
# senza dipendere da Functions_20570.R del corso.

cat("============================================================\n")
cat("STEP 5: PCA + FACTOR ANALYSIS — ITALY\n")
cat("============================================================\n\n")


# --- 0. LOAD DATA -----------------------------------------------------------

italy_std   <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_std.rds"))
italy_clean <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_clean.rds"))
cat("  Loaded step2_italy_std.rds:", nrow(italy_std), "rows\n")
cat("  Loaded step2_italy_clean.rds:", nrow(italy_clean), "rows\n\n")

# --- Definizione variabili ---
health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")

all_31 <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

# --- Check varianza zero ---
zero_var_check <- sapply(italy_std[, all_31], sd)
zero_vars <- names(zero_var_check[zero_var_check == 0])
cat("  Variabili a varianza zero:",
    ifelse(length(zero_vars) > 0, paste(zero_vars, collapse = ", "), "nessuna"), "\n")

# Variabili attive per PCA/FA (escludendo zero-variance)
active_vars <- setdiff(all_31, zero_vars)
cat("  Variabili attive per PCA/FA:", length(active_vars), "\n\n")

# Digital vars senza zero-variance
digital_active <- setdiff(digital_vars, zero_vars)


# ##############################################################################
# PART A: DIMENSION-WISE PCA
# ##############################################################################

cat("============================================================\n")
cat("PART A: DIMENSION-WISE PCA\n")
cat("============================================================\n\n")

# Funzione helper per PCA su un blocco di variabili
# force_n: se specificato, impone il numero di PC da riportare (es. per allineare al brief)
run_pca_block <- function(data_std, vars, block_name, force_n = NULL) {
  cat("--- PCA:", block_name, "(", length(vars), "variabili) ---\n")

  # Matrice dati standardizzati
  X <- as.matrix(data_std[, vars])

  # Matrice di correlazione
  R <- cor(X)

  # Eigenvalue decomposition
  eig <- eigen(R)
  eigenvalues <- eig$values
  eigenvectors <- eig$vectors

  # Varianza spiegata
  prop_var <- eigenvalues / sum(eigenvalues)
  cum_var  <- cumsum(prop_var)

  cat("  Eigenvalues:\n")
  for (i in seq_along(eigenvalues)) {
    cat(sprintf("    PC%d: %.4f (%.1f%%, cum: %.1f%%)\n",
                i, eigenvalues[i], 100 * prop_var[i], 100 * cum_var[i]))
  }

  # Kaiser's rule: eigenvalue > 1
  n_kaiser <- sum(eigenvalues > 1)
  cat("  Kaiser's rule: ", n_kaiser, "PC(s) con eigenvalue > 1\n")

  # Numero di PC da riportare: force_n se fornito, altrimenti Kaiser
  if (!is.null(force_n)) {
    n_report <- force_n
    if (n_report != n_kaiser) {
      cat(sprintf("  NOTA: forzati %d PC (brief) invece di %d (Kaiser). ",
                  n_report, n_kaiser))
      cat(sprintf("PC%d eigenvalue = %.3f\n", n_report, eigenvalues[n_report]))
    }
  } else {
    n_report <- n_kaiser
  }

  # PC scores (Data.std %*% eigenvectors)
  PC_scores <- X %*% eigenvectors
  colnames(PC_scores) <- paste0("PC", 1:ncol(PC_scores))

  # Correlazione variabili-PC (loadings = eigenvectors * sqrt(eigenvalues))
  loadings <- eigenvectors %*% diag(sqrt(eigenvalues))
  rownames(loadings) <- vars
  colnames(loadings) <- paste0("PC", 1:ncol(loadings))

  # Squared cosines (cos2 = loadings^2)
  cos2 <- loadings^2

  cat("\n  Loadings (correlazioni var-PC) per i primi", n_report, "PC:\n")
  cat("  Variabile              |", paste(sprintf(" PC%-4d", 1:n_report), collapse = "|"), "\n")
  cat("  ", paste(rep("-", 24 + n_report * 8), collapse = ""), "\n")
  for (i in seq_along(vars)) {
    vals <- sprintf("%6.3f", loadings[i, 1:n_report])
    cat(sprintf("  %-22s | %s\n", vars[i], paste(vals, collapse = " | ")))
  }

  cat("\n  Squared cosines (qualità rappresentazione) per i primi", n_report, "PC:\n")
  for (i in seq_along(vars)) {
    vals <- sprintf("%6.3f", cos2[i, 1:n_report])
    total <- sum(cos2[i, 1:n_report])
    cat(sprintf("  %-22s | %s | tot: %.3f\n", vars[i], paste(vals, collapse = " | "), total))
  }

  cat("\n")

  return(list(
    block_name   = block_name,
    vars         = vars,
    cor_matrix   = R,
    eigenvalues  = eigenvalues,
    prop_var     = prop_var,
    cum_var      = cum_var,
    n_kaiser     = n_kaiser,
    n_report     = n_report,
    eigenvectors = eigenvectors,
    loadings     = loadings,
    cos2         = cos2,
    PC_scores    = PC_scores
  ))
}


# --- A1. HEALTH (8 variabili → attesi 2 PC) ---
pca_health <- run_pca_block(italy_std, health_vars, "Health")

# --- A2. ECONOMIC (5 variabili → attesi 2 PC) ---
pca_econ <- run_pca_block(italy_std, econ_vars, "Economic")

# --- A3. DIGITAL/SOCIAL (8 variabili attive → attesi 4 PC) ---
# NB: ac035d4 e ac035d7 escluse per varianza zero.
# NB: Kaiser rigoroso dà 3 PC (PC4 eigenvalue ≈ 0.96, borderline) ma il brief
# del progetto usa 4 PC (digit_PC4 è usato per flag outlier, vedi brief §).
# Forziamo quindi 4 PC per coerenza con il disegno originale del brief.
pca_digital <- run_pca_block(italy_std, digital_active, "Digital/Social", force_n = 4)

# --- A4. COGNITIVE (3 variabili → atteso 1 PC) ---
pca_cog <- run_pca_block(italy_std, cog_vars, "Cognitive")

# --- A5. SUBJECTIVE (5 variabili → atteso 1 PC) ---
pca_subj <- run_pca_block(italy_std, subj_vars, "Subjective")


# --- RIEPILOGO PCA ---
cat("\n============================================================\n")
cat("RIEPILOGO PCA PER DIMENSIONE\n")
cat("============================================================\n")
cat(sprintf("  %-18s | Vars | PCs rep | Kaiser | Var expl\n", "Dimensione"))
cat("  ", paste(rep("-", 60), collapse = ""), "\n")

pca_list <- list(pca_health, pca_econ, pca_digital, pca_cog, pca_subj)
for (p in pca_list) {
  nr <- p$n_report
  nk <- p$n_kaiser
  var_expl <- p$cum_var[nr]
  flag <- ifelse(nr != nk, "*", " ")
  cat(sprintf("  %-18s | %4d | %6d%s | %6d | %7.1f%%\n",
              p$block_name, length(p$vars), nr, flag, nk, 100 * var_expl))
}
cat("  (* = forzato al numero del brief, diverso da Kaiser)\n")

total_pcs <- sum(sapply(pca_list, function(p) p$n_report))
cat("  Totale PC selezionati:", total_pcs, "\n\n")


# ##############################################################################
# PART B: FACTOR ANALYSIS (tutte le variabili attive → 6 fattori)
# ##############################################################################

cat("============================================================\n")
cat("PART B: FACTOR ANALYSIS\n")
cat("============================================================\n\n")


# --- B1. KMO & BARTLETT TEST ------------------------------------------------

X_fa <- as.matrix(italy_std[, active_vars])
R_fa <- cor(X_fa)

kmo_result <- KMO(R_fa)
cat("--- KMO Test ---\n")
cat("  Overall MSA:", round(kmo_result$MSA, 3), "\n")
cat("  (> 0.6 = acceptable, > 0.7 = middling, > 0.8 = meritorious)\n\n")

bart <- cortest.bartlett(R_fa, n = nrow(X_fa))
cat("--- Bartlett's Test of Sphericity ---\n")
cat("  Chi-squared:", round(bart$chisq, 2), "\n")
cat("  df:", bart$df, "\n")
cat("  p-value:", format.pval(bart$p.value, digits = 3), "\n")
cat("  (p < 0.05 → correlations are significantly different from identity)\n\n")


# --- B2. PARALLEL ANALYSIS ---------------------------------------------------

cat("--- Parallel Analysis ---\n")
cat("  (Determina il numero ottimale di fattori)\n")

set.seed(42)
pa_result <- fa.parallel(X_fa, fm = "pa", fa = "fa", n.iter = 100,
                         main = "Parallel Analysis — Italy",
                         show.legend = TRUE)

cat("  Fattori suggeriti da parallel analysis:", pa_result$nfact, "\n")
cat("  Componenti suggerite:", pa_result$ncomp, "\n\n")


# --- B3. SCREE PLOT (eigenvalues) --------------------------------------------

eig_full <- eigen(R_fa)$values
cat("--- Eigenvalues (full correlation matrix, 29 variabili) ---\n")
for (i in 1:min(10, length(eig_full))) {
  cat(sprintf("  PC%2d: %.4f (%.1f%%, cum: %.1f%%)\n",
              i, eig_full[i],
              100 * eig_full[i] / sum(eig_full),
              100 * sum(eig_full[1:i]) / sum(eig_full)))
}
cat("  ...\n\n")


# --- B4. FACTOR ANALYSIS: 6 FATTORI, VARIMAX --------------------------------

cat("--- Factor Analysis: 6 fattori, PA extraction, varimax rotation ---\n\n")

# Metodo iterativo: Principal Axis (fm="pa") con rotazione varimax
# Questo è il metodo raccomandato nel corso (HandsOn_FA)
fa_result <- fa(X_fa, nfactors = 6, rotate = "varimax", fm = "pa",
                scores = "regression", n.iter = 1)

# Loadings
cat("  FACTOR LOADINGS (varimax, cut = 0.30):\n")
print(fa_result$loadings, cutoff = 0.30, sort = TRUE)

cat("\n  FACTOR LOADINGS (completi, ordinati per fattore):\n")
# Ordina le variabili per fattore dominante
loadings_mat <- as.matrix(fa_result$loadings)

# Per ogni variabile, trova il fattore con loading più alto
max_factor <- apply(abs(loadings_mat), 1, which.max)
max_loading <- apply(abs(loadings_mat), 1, max)

# Ordina per fattore, poi per loading decrescente
var_order <- order(max_factor, -max_loading)

cat(sprintf("  %-22s |", "Variable"))
for (f in 1:6) cat(sprintf("  PA%-2d ", f))
cat("| h2     | u2    | Max Factor\n")
cat("  ", paste(rep("-", 100), collapse = ""), "\n")

for (i in var_order) {
  v <- active_vars[i]
  cat(sprintf("  %-22s |", v))
  for (f in 1:6) {
    val <- loadings_mat[i, f]
    if (abs(val) >= 0.30) {
      cat(sprintf(" %5.2f*", val))
    } else {
      cat(sprintf(" %5.2f ", val))
    }
  }
  cat(sprintf("| %.3f  | %.3f | PA%d\n",
              fa_result$communality[i],
              fa_result$uniquenesses[i],
              max_factor[i]))
}


# --- B5. COMMUNALITIES -------------------------------------------------------

cat("\n--- Communalities ---\n")
comm <- fa_result$communality
cat("  Variabile              | h2     | Qualità\n")
cat("  ", paste(rep("-", 45), collapse = ""), "\n")
for (v in active_vars[order(-comm)]) {
  h2 <- comm[v]
  quality <- ifelse(h2 > 0.5, "buona", ifelse(h2 > 0.3, "moderata", "bassa"))
  cat(sprintf("  %-22s | %.3f  | %s\n", v, h2, quality))
}
cat(sprintf("\n  Media communalities: %.3f\n", mean(comm)))
cat(sprintf("  Min:                 %.3f (%s)\n", min(comm), names(which.min(comm))))
cat(sprintf("  Max:                 %.3f (%s)\n", max(comm), names(which.max(comm))))


# --- B6. FACTOR FIT STATISTICS -----------------------------------------------

cat("\n--- Fit Statistics ---\n")
cat("  RMSR (Root Mean Square Residual):", round(fa_result$rms, 4), "\n")
cat("  TLI (Tucker-Lewis Index):        ", round(fa_result$TLI, 4), "\n")
cat("  RMSEA:                           ", round(fa_result$RMSEA[1], 4), "\n")
cat("  BIC:                             ", round(fa_result$BIC, 2), "\n")

# Residual correlation matrix
residuals_mat <- fa_result$residual
if (!is.null(residuals_mat)) {
  # Off-diagonal residuals
  off_diag <- residuals_mat[upper.tri(residuals_mat)]
  cat("  Residui off-diagonal:\n")
  cat("    Mean:   ", round(mean(abs(off_diag)), 4), "\n")
  cat("    Median: ", round(median(abs(off_diag)), 4), "\n")
  cat("    Max:    ", round(max(abs(off_diag)), 4), "\n")
  cat("    % > 0.05:", round(100 * mean(abs(off_diag) > 0.05), 1), "%\n")
}

# Proportion Var e SS loadings per fattore
cat("\n  SS Loadings e varianza spiegata per fattore:\n")
ss <- colSums(loadings_mat^2)
prop <- ss / length(active_vars)
cum_prop <- cumsum(prop)
cat(sprintf("  %-8s | SS Load | Prop Var | Cum Var\n", "Factor"))
cat("  ", paste(rep("-", 42), collapse = ""), "\n")
for (f in 1:6) {
  cat(sprintf("  PA%-5d | %7.2f | %8.3f | %7.3f\n",
              f, ss[f], prop[f], cum_prop[f]))
}
cat(sprintf("\n  Varianza totale spiegata dai 6 fattori: %.1f%%\n", 100 * cum_prop[6]))


# --- B7. FACTOR SCORES -------------------------------------------------------

cat("\n--- Factor Scores ---\n")
factor_scores <- fa_result$scores
colnames(factor_scores) <- paste0("FA", 1:6)
cat("  Calcolati factor scores per", nrow(factor_scores), "osservazioni\n")
cat("  (Questi verranno usati SOLO per le mappe fattoriali,\n")
cat("   NON per il clustering — Trentini: cluster su variabili originali std)\n\n")

# Verifica: media ≈ 0, sd ≈ 1
for (f in 1:6) {
  cat(sprintf("  FA%d: mean=%.4f, sd=%.4f\n", f,
              mean(factor_scores[, f]), sd(factor_scores[, f])))
}


# --- B8. FACTOR INTERPRETATION (dinamica dai loadings effettivi) -------------

cat("\n============================================================\n")
cat("INTERPRETAZIONE DEI FATTORI (data-driven)\n")
cat("============================================================\n")
cat("  Per ogni fattore: variabili con |loading| >= 0.30, ordinate per |loading|\n")
cat("  Il nome del fattore è ASSEGNATO EURISTICAMENTE in base al gruppo tematico\n")
cat("  dominante (health/econ/digital/cog/subj) tra le variabili con loading alto.\n")
cat("  NB: i numeri PA1..PA6 sono arbitrari (psych li assegna per ordine di\n")
cat("  estrazione); ciò che conta è il contenuto semantico dei fattori.\n\n")

# Mappa variabile → dimensione tematica (per labelling euristico)
dim_map <- c(
  setNames(rep("Health",    length(health_vars)),  health_vars),
  setNames(rep("Economic",  length(econ_vars)),    econ_vars),
  setNames(rep("Digital",   length(digital_vars)), digital_vars),
  setNames(rep("Cognitive", length(cog_vars)),     cog_vars),
  setNames(rep("Subjective",length(subj_vars)),    subj_vars)
)

# Loadings candidate del brief per confronto (linee 174-179 del brief)
brief_mapping <- data.frame(
  label = c("Fragilità fisica", "Patrimonio", "Rete sociale",
            "Reddito", "Engagement digitale-cognitivo", "Benessere soggettivo"),
  key_vars = c("mobility,iadl,sphus,adl,chronic",
               "log_hnetw,home_own",
               "social_integration,sn_size_w9",
               "log_thinc,ypen1",
               "ac035d8,fluency,internet,memory,ac035d1",
               "eurod,casp,loneliness,hope_future,interest,expect_alive"),
  stringsAsFactors = FALSE
)

# Per ogni fattore PA1..PA6, identifica variabili salienti e etichetta
factor_summary <- list()
for (f in 1:6) {
  col_name <- colnames(loadings_mat)[f]
  ld <- loadings_mat[, f]
  sel <- which(abs(ld) >= 0.30)
  if (length(sel) == 0) {
    # Se nessun loading ≥ 0.30, prendi i 3 più alti
    sel <- order(-abs(ld))[1:3]
  }
  # Ordina per |loading| decrescente
  sel <- sel[order(-abs(ld[sel]))]

  vars_sel <- active_vars[sel]
  lds_sel  <- ld[sel]
  dims_sel <- dim_map[vars_sel]

  # Dimensione dominante (moda)
  dim_table <- table(dims_sel)
  dom_dim <- names(dim_table)[which.max(dim_table)]

  # Match al brief: trova la label del brief con più overlap di variabili chiave
  overlap <- sapply(brief_mapping$key_vars, function(kv) {
    brief_vars <- strsplit(kv, ",")[[1]]
    sum(vars_sel %in% brief_vars)
  })
  best_match <- which.max(overlap)
  brief_label <- if (overlap[best_match] >= 2) brief_mapping$label[best_match] else "(no match)"

  cat(sprintf("  %s  →  [%s]  (dim. dominante: %s)\n",
              col_name, brief_label, dom_dim))
  cat("    Variabili salienti (|loading| >= 0.30, ordinate per |loading|):\n")
  for (k in seq_along(vars_sel)) {
    cat(sprintf("      %-22s  %6.3f   [%s]\n",
                vars_sel[k], lds_sel[k], dims_sel[k]))
  }
  cat("\n")

  factor_summary[[col_name]] <- list(
    brief_label = brief_label,
    dominant_dim = dom_dim,
    salient_vars = vars_sel,
    salient_loadings = lds_sel
  )
}

cat("  NOTA: le etichette del brief sono abbinate per overlap di variabili chiave.\n")
cat("  Controllare che ogni fattore abbia un match semantico sensato.\n\n")


# --- B9. PARALLEL ANALYSIS: CONFRONTO N. FATTORI -----------------------------

cat("\n--- Confronto numero di fattori ---\n")
cat("  Parallel analysis suggerisce:", pa_result$nfact, "fattori\n")
cat("  Brief del progetto usa:       6 fattori\n")
cat("  Kaiser's rule (eigenvalue>1): ", sum(eig_full > 1), "componenti\n")

# Test fit per diversi numeri di fattori
cat("\n  Fit comparison (4-8 fattori):\n")
cat(sprintf("  %-10s | %-8s | %-8s | %-8s | %-8s\n", "nFactors", "RMSR", "TLI", "RMSEA", "BIC"))
cat("  ", paste(rep("-", 52), collapse = ""), "\n")
for (nf in 4:8) {
  tryCatch({
    fa_test <- fa(X_fa, nfactors = nf, rotate = "varimax", fm = "pa",
                  warnings = FALSE)
    cat(sprintf("  %-10d | %8.4f | %8.4f | %8.4f | %8.1f\n",
                nf, fa_test$rms, fa_test$TLI, fa_test$RMSEA[1], fa_test$BIC))
  }, error = function(e) {
    cat(sprintf("  %-10d | errore: %s\n", nf, e$message))
  })
}


# ##############################################################################
# SALVATAGGIO
# ##############################################################################

cat("\n============================================================\n")
cat("SALVATAGGIO RISULTATI\n")
cat("============================================================\n")

# Salva risultati PCA
pca_results <- list(
  health   = pca_health,
  economic = pca_econ,
  digital  = pca_digital,
  cognitive = pca_cog,
  subjective = pca_subj,
  zero_var_excluded = zero_vars,
  active_vars = active_vars,
  n_obs = nrow(italy_std)
)
saveRDS(pca_results, file.path(data_path, "v9", "outputs", "step5_italy_pca_results.rds"))
cat("  Salvato: v9/step5_italy_pca_results.rds\n")

# Salva risultati FA
fa_results <- list(
  fa_model        = fa_result,
  loadings        = loadings_mat,
  communalities   = fa_result$communality,
  uniquenesses    = fa_result$uniquenesses,
  factor_scores   = factor_scores,
  factor_summary  = factor_summary,   # etichette data-driven per ciascun PA
  fa_course       = fa_course,        # FA del corso (se disponibile)
  fit_stats       = list(
    RMSR  = fa_result$rms,
    TLI   = fa_result$TLI,
    RMSEA = fa_result$RMSEA[1],
    BIC   = fa_result$BIC
  ),
  parallel_analysis = pa_result,
  active_vars       = active_vars,
  zero_var_excluded = zero_vars,
  n_factors         = 6,
  n_obs             = nrow(italy_std)
)
saveRDS(fa_results, file.path(data_path, "v9", "outputs", "step5_italy_fa_results.rds"))
cat("  Salvato: v9/step5_italy_fa_results.rds\n")

# Salva anche i factor scores nel dataset per uso successivo (mappe fattoriali)
italy_with_scores <- cbind(italy_clean, factor_scores)
saveRDS(italy_with_scores, file.path(data_path, "v9", "outputs", "step5_italy_with_fa_scores.rds"))
cat("  Salvato: v9/step5_italy_with_fa_scores.rds (dati + factor scores)\n")


# ##############################################################################
# RIEPILOGO FINALE
# ##############################################################################

cat("\n============================================================\n")
cat("RIEPILOGO STEP 5 — ITALY\n")
cat("============================================================\n")
cat("  Osservazioni:       ", nrow(italy_std), "\n")
cat("  Variabili totali:    31\n")
cat("  Variabili escluse:  ", paste(zero_vars, collapse = ", "), "(varianza zero)\n")
cat("  Variabili attive:   ", length(active_vars), "\n\n")

cat("  PCA per dimensione:\n")
for (p in pca_list) {
  flag <- ifelse(p$n_report != p$n_kaiser, " [forzato]", "")
  cat(sprintf("    %-18s: %d var → %d PC (%.1f%% var expl)%s\n",
              p$block_name, length(p$vars), p$n_report,
              100 * p$cum_var[p$n_report], flag))
}
cat(sprintf("    TOTALE: %d PC\n\n", total_pcs))

cat("  Factor Analysis:\n")
cat("    Metodo: Principal Axis (pa), varimax rotation\n")
cat("    N. fattori: 6\n")
cat(sprintf("    Varianza spiegata: %.1f%%\n", 100 * cum_prop[6]))
cat(sprintf("    RMSR: %.4f\n", fa_result$rms))
cat(sprintf("    Media communalities: %.3f\n", mean(comm)))
cat(sprintf("    KMO: %.3f\n\n", kmo_result$MSA))

cat("  NOTA IMPORTANTE:\n")
cat("  Il clustering (Step 6) si farà sulle 31 variabili ORIGINALI STANDARDIZZATE\n")
cat("  (step2_italy_std.rds), NON sui factor scores.\n")
cat("  I factor scores servono SOLO per le mappe fattoriali post-clustering.\n")

cat("\n============================================================\n")
cat("STEP 5 COMPLETATO.\n")
cat("Prossimo step: PCA + FA Sweden (Step 6) o Clustering Italy (Step 7)\n")
cat("============================================================\n")
