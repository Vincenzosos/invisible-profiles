# ==============================================================================
# STEP 10: LATENT CLASS ANALYSIS (LCA) — ITALY & SWEDEN
# Thesis: "Invisible Profiles"
#
# Terzo approccio metodologico (brief line 212: "3 approcci — PCA+kmeans, FA, LCA").
# LCA tratta i profili come "latent classes" probabilistiche, usando solo variabili
# categoriche. Valida la scelta k delle k-means via BIC/AIC + entropia, e quantifica
# la "convergenza" tra assegnazioni k-means e LCA (brief line 188-189:
# "Convergenza Connected 70%, Fragile 51%").
#
# Pipeline:
#   Part A — Discretizzazione delle 20 var non-binarie in terzili (low/mid/high)
#   Part B — Fit poLCA per k=2..8 per Italia e Svezia
#   Part C — Model selection via BIC + Entropia + χ²
#   Part D — Compare LCA k=5 (IT) e k=6 (SE) con k-means via confusion matrix
#   Part E — Convergenza per profilo
#   Part F — Salvataggio
#
# INPUT:  v9/step7_italy_with_clusters.rds
#         v9/step8_sweden_with_clusters.rds
# OUTPUT: v9/step10_lca_italy.rds
#         v9/step10_lca_sweden.rds
#         v9/step10_convergence_table.rds
# ==============================================================================

library(dplyr)

# Install poLCA se mancante
if (!requireNamespace("poLCA", quietly = TRUE)) {
  cat("  Installing 'poLCA' package...\n")
  install.packages("poLCA", quiet = TRUE)
}
library(poLCA)

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"

cat("============================================================\n")
cat("STEP 10: LATENT CLASS ANALYSIS (LCA)\n")
cat("============================================================\n\n")


# --- 0. LOAD DATA -----------------------------------------------------------

italy  <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
sweden <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_with_clusters.rds"))

cat("  Loaded italy  (Step 7):", nrow(italy),  "rows\n")
cat("  Loaded sweden (Step 8):", nrow(sweden), "rows\n\n")

# --- Definizione variabili (31) ---
health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")
all_31       <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

binary_vars <- c("phinact", "home_own", "internet", "ac035d1", "ac035d5",
                 "ac035d8", "sp002_", "sp008_", "ac035d4", "ac035d7", "hope_future")
nonbinary_vars <- setdiff(all_31, binary_vars)


# ##############################################################################
# PART A: DISCRETIZZAZIONE (poLCA richiede solo categoriche)
# ##############################################################################

cat("============================================================\n")
cat("PART A: DISCRETIZZAZIONE VARIABILI\n")
cat("============================================================\n\n")

# Per poLCA: ogni variabile deve essere categoriale con codici 1..K positivi.
# Strategia:
#   - Variabili binarie (11): ricoded in 1/2 (da 0/1)
#   - Variabili non-binarie (20): tertili (1=low, 2=mid, 3=high)
#
# Escludiamo ac035d4/ac035d7 da Italia (zero-variance).

discretize_for_lca <- function(df, active_bin, active_nonbin) {
  out <- data.frame(row.names = seq_len(nrow(df)))
  # Binarie: da 0/1 a 1/2
  for (v in active_bin) {
    vals <- df[[v]]
    out[[v]] <- ifelse(vals == 0, 1, ifelse(vals == 1, 2, NA))
  }
  # Non-binarie: discretizzazione robusta ai tie (es. adl ha molti zero)
  for (v in active_nonbin) {
    vals <- df[[v]]
    q1 <- quantile(vals, probs = 1/3, na.rm = TRUE)
    q2 <- quantile(vals, probs = 2/3, na.rm = TRUE)

    # Se i due tertili coincidono, prova strategie alternative
    if (q1 == q2) {
      # Strategia 1: split binario se tutta la varianza è a un lato
      n_unique <- length(unique(vals[!is.na(vals)]))
      if (n_unique < 3) {
        # Solo 2 valori: binary split
        q1_val <- min(vals, na.rm = TRUE)
        out[[v]] <- ifelse(is.na(vals), NA,
                           ifelse(vals == q1_val, 1, 2))
        cat(sprintf("    %-22s: only %d unique values → binary coded\n",
                    v, n_unique))
        next
      }
      # Strategia 2: split per valore soglia = max tra min e q2
      # Se >50% è allo stesso valore, separiamo "0 vs >0"
      mode_val <- as.numeric(names(sort(table(vals), decreasing = TRUE)[1]))
      mode_pct <- mean(vals == mode_val, na.rm = TRUE)
      if (mode_pct >= 0.5) {
        # Gruppo 1: valore modale | Gruppo 2: sopra la moda | Gruppo 3: (se esiste) sopra q3
        q3 <- quantile(vals[vals > mode_val], probs = 0.5, na.rm = TRUE)
        if (!is.na(q3) && q3 > mode_val) {
          out[[v]] <- ifelse(is.na(vals), NA,
                             ifelse(vals <= mode_val, 1,
                                    ifelse(vals <= q3, 2, 3)))
          cat(sprintf("    %-22s: mode-based split (mode=%.1f, q3 upper=%.1f)\n",
                      v, mode_val, q3))
        } else {
          # Solo binary: modal vs not
          out[[v]] <- ifelse(is.na(vals), NA,
                             ifelse(vals == mode_val, 1, 2))
          cat(sprintf("    %-22s: binary split at mode=%.1f (%.0f%%)\n",
                      v, mode_val, 100 * mode_pct))
        }
      } else {
        # Fallback: forza tertili unici
        breaks <- unique(c(-Inf, q1, q2, Inf))
        if (length(breaks) < 3) breaks <- c(-Inf, median(vals, na.rm = TRUE), Inf)
        cat_v <- cut(vals, breaks = breaks, include.lowest = TRUE)
        out[[v]] <- as.integer(cat_v)
        cat(sprintf("    %-22s: forced %d-level split\n", v, length(breaks) - 1))
      }
    } else {
      # Caso normale: tertili
      cat_v <- cut(vals, breaks = c(-Inf, q1, q2, Inf),
                   labels = c(1, 2, 3), include.lowest = TRUE)
      out[[v]] <- as.integer(as.character(cat_v))
    }
  }
  return(out)
}

# Italia: attive = setdiff(all_31, c("ac035d4", "ac035d7"))
italy_active <- setdiff(all_31, c("ac035d4", "ac035d7"))
italy_bin_active <- intersect(binary_vars,    italy_active)
italy_nb_active  <- intersect(nonbinary_vars, italy_active)

italy_lca_df <- discretize_for_lca(italy, italy_bin_active, italy_nb_active)
italy_lca_df$cluster_km <- italy$cluster_num     # mantiene l'assegnazione k-means
italy_lca_df$profile_km <- as.character(italy$profile)
cat(sprintf("  Italia: %d osservazioni, %d variabili categoriche attive\n",
            nrow(italy_lca_df), length(italy_active)))

# Svezia: tutte 31 attive
sweden_active <- all_31
sweden_bin_active <- intersect(binary_vars,    sweden_active)
sweden_nb_active  <- intersect(nonbinary_vars, sweden_active)

sweden_lca_df <- discretize_for_lca(sweden, sweden_bin_active, sweden_nb_active)
sweden_lca_df$cluster_km <- sweden$cluster_num
sweden_lca_df$profile_km <- as.character(sweden$profile)
cat(sprintf("  Svezia: %d osservazioni, %d variabili categoriche attive\n\n",
            nrow(sweden_lca_df), length(sweden_active)))


# ##############################################################################
# PART B: FIT LCA k=2..8 PER CIASCUN PAESE
# ##############################################################################

cat("============================================================\n")
cat("PART B: FIT LCA k=2..8\n")
cat("============================================================\n\n")

# Costruisci formula poLCA: cbind(var1, var2, ...) ~ 1 (no covariate)
make_formula <- function(vars) {
  as.formula(paste("cbind(", paste(vars, collapse = ", "), ") ~ 1"))
}

# Funzione per computare entropia normalizzata (0-1, 1 = class separation perfetta)
compute_entropy <- function(lca_fit) {
  post <- lca_fit$posterior
  K <- ncol(post)
  N <- nrow(post)
  # Entropia per-osservazione: -Σ p * log(p)
  entropy_per_obs <- -rowSums(post * log(post + 1e-20), na.rm = TRUE)
  E <- sum(entropy_per_obs)
  # Normalizzato: 1 - E / (N log K)
  1 - E / (N * log(K))
}

fit_lca_sequence <- function(df, vars, k_range, country_label, max_iter = 1000, nrep = 5) {
  formula_lca <- make_formula(vars)
  # Rimuovi righe con NA nelle variabili attive
  df_complete <- df[complete.cases(df[, vars]), ]
  cat(sprintf("  %s: %d righe complete / %d totali\n",
              country_label, nrow(df_complete), nrow(df)))

  results_list <- list()
  fit_tab <- data.frame(
    k = integer(), log_lik = numeric(), bic = numeric(),
    aic = numeric(), entropy = numeric(), chisq = numeric(),
    n_class_sizes = character()
  )

  for (k in k_range) {
    cat(sprintf("    Fitting k=%d...", k))
    set.seed(42)
    fit <- tryCatch(
      suppressMessages(poLCA(formula_lca, data = df_complete, nclass = k,
                             maxiter = max_iter, nrep = nrep, verbose = FALSE,
                             na.rm = TRUE)),
      error = function(e) {
        cat(" ERRORE:", e$message, "\n")
        NULL
      }
    )
    if (is.null(fit)) next

    ent <- compute_entropy(fit)
    class_sizes <- round(fit$P * nrow(df_complete))
    cat(sprintf(" BIC=%.1f  entropy=%.3f  sizes=[%s]\n",
                fit$bic, ent,
                paste(class_sizes, collapse = ",")))

    results_list[[as.character(k)]] <- list(
      fit       = fit,
      entropy   = ent,
      class_sizes = class_sizes
    )
    fit_tab <- rbind(fit_tab, data.frame(
      k             = k,
      log_lik       = fit$llik,
      bic           = fit$bic,
      aic           = fit$aic,
      entropy       = ent,
      chisq         = fit$Chisq,
      n_class_sizes = paste(class_sizes, collapse = ","),
      stringsAsFactors = FALSE
    ))
  }

  list(fit_tab = fit_tab, fits = results_list, n_complete = nrow(df_complete))
}

# --- Italia: k=2..8 ---
cat("Italia LCA fits:\n")
it_lca <- fit_lca_sequence(italy_lca_df, italy_active, 2:8, "Italia")

# --- Svezia: k=2..8 ---
cat("\nSvezia LCA fits:\n")
se_lca <- fit_lca_sequence(sweden_lca_df, sweden_active, 2:8, "Svezia")


# ##############################################################################
# PART C: MODEL SELECTION VIA BIC + ENTROPIA
# ##############################################################################

cat("\n============================================================\n")
cat("PART C: MODEL SELECTION\n")
cat("============================================================\n\n")

cat("Italia — fit statistics:\n")
print(it_lca$fit_tab, row.names = FALSE)
cat(sprintf("\n  BIC ottimale: k=%d\n", it_lca$fit_tab$k[which.min(it_lca$fit_tab$bic)]))
cat(sprintf("  Entropia max: k=%d (%.3f)\n",
            it_lca$fit_tab$k[which.max(it_lca$fit_tab$entropy)],
            max(it_lca$fit_tab$entropy)))
cat("  Brief dichiarava: k=6 via BIC, entropia 0.831\n\n")

cat("Svezia — fit statistics:\n")
print(se_lca$fit_tab, row.names = FALSE)
cat(sprintf("\n  BIC ottimale: k=%d\n", se_lca$fit_tab$k[which.min(se_lca$fit_tab$bic)]))
cat(sprintf("  Entropia max: k=%d (%.3f)\n",
            se_lca$fit_tab$k[which.max(se_lca$fit_tab$entropy)],
            max(se_lca$fit_tab$entropy)))
cat("  Brief dichiarava: k=6 via BIC, entropia 0.833\n\n")


# ##############################################################################
# PART D: CONFRONTO LCA vs K-MEANS (confusion matrix)
# ##############################################################################

cat("============================================================\n")
cat("PART D: CONFRONTO LCA vs K-MEANS (confusion matrix)\n")
cat("============================================================\n\n")

# Usiamo k=5 per Italia (come k-means) e k=6 per Svezia
compare_lca_kmeans <- function(lca_results, df_full, df_complete_subset, k_target,
                                country_label) {
  if (is.null(lca_results$fits[[as.character(k_target)]])) {
    cat(sprintf("  %s: k=%d non disponibile in LCA fits\n", country_label, k_target))
    return(NULL)
  }

  fit    <- lca_results$fits[[as.character(k_target)]]$fit
  lca_cl <- fit$predclass

  # Match LCA assignment agli indici del df originale completo
  idx_complete <- which(complete.cases(df_full[, attr(fit$formula, "term.labels")]))
  # In alternativa, usiamo lo stesso ordine di df_complete_subset
  idx_complete <- which(!is.na(rowSums(df_full[, attr(fit$formula, "term.labels")])))

  # Allineamento via LCA posterior order (LCA keeps order of df_complete)
  # Il df_complete è quello passato a poLCA (row order preservato).

  # Per confronto: prendiamo i profili k-means sugli stessi indici
  profile_km <- df_full$profile_km
  # Attenzione: solo righe complete sono state usate da LCA
  complete_mask <- complete.cases(df_full[, attr(fit$formula, "term.labels")])
  profile_km_complete <- profile_km[complete_mask]

  conf_tab <- table(LCA = lca_cl, Kmeans = profile_km_complete)
  cat(sprintf("\n%s — Confusion Matrix (LCA rows × K-means profile columns):\n", country_label))
  print(conf_tab)

  # Convergenza per profilo: per ogni profile k-means, % di membri che sono nella
  # LCA class dominante (il mode)
  cat(sprintf("\n  Convergenza per profilo k-means:\n"))
  profile_vec <- unique(profile_km_complete)
  conv_rows <- list()
  for (prof in profile_vec) {
    members_of_profile <- which(profile_km_complete == prof)
    lca_of_members <- lca_cl[members_of_profile]
    tab <- table(lca_of_members)
    dom_class <- as.integer(names(tab)[which.max(tab)])
    n_dom <- max(tab)
    n_tot <- length(members_of_profile)
    conv_pct <- 100 * n_dom / n_tot
    cat(sprintf("    %-20s: n=%d → LCA class %d domina (n=%d, %.1f%%)\n",
                prof, n_tot, dom_class, n_dom, conv_pct))
    conv_rows[[length(conv_rows)+1]] <- data.frame(
      country = country_label,
      profile = prof,
      n_profile = n_tot,
      dominant_lca_class = dom_class,
      n_in_dominant = n_dom,
      convergence_pct = conv_pct
    )
  }

  # Convergenza globale: % di righe dove (profilo k-means, LCA class dominante) coincide
  global_conv <- 0
  total <- length(lca_cl)
  for (prof in profile_vec) {
    members_of_profile <- which(profile_km_complete == prof)
    if (length(members_of_profile) == 0) next
    lca_of_members <- lca_cl[members_of_profile]
    tab <- table(lca_of_members)
    dom_class <- as.integer(names(tab)[which.max(tab)])
    global_conv <- global_conv + sum(lca_of_members == dom_class)
  }
  cat(sprintf("\n  Convergenza GLOBALE: %d/%d (%.1f%%)\n",
              global_conv, total, 100 * global_conv / total))

  list(conf_tab = conf_tab,
       convergence_by_profile = do.call(rbind, conv_rows),
       global_convergence = 100 * global_conv / total)
}

italy_compare  <- compare_lca_kmeans(it_lca, italy_lca_df, NULL, 5, "Italia")
sweden_compare <- compare_lca_kmeans(se_lca, sweden_lca_df, NULL, 6, "Svezia")


# ##############################################################################
# PART E: SALVATAGGIO
# ##############################################################################

cat("\n============================================================\n")
cat("SALVATAGGIO RISULTATI\n")
cat("============================================================\n")

saveRDS(list(fit_tab = it_lca$fit_tab, fits = it_lca$fits,
             comparison = italy_compare),
        file.path(data_path, "v9", "outputs", "step10_lca_italy.rds"))
cat("  Salvato: v9/step10_lca_italy.rds\n")

saveRDS(list(fit_tab = se_lca$fit_tab, fits = se_lca$fits,
             comparison = sweden_compare),
        file.path(data_path, "v9", "outputs", "step10_lca_sweden.rds"))
cat("  Salvato: v9/step10_lca_sweden.rds\n")

# Tabella convergenza combinata (stile brief line 186-189)
if (!is.null(italy_compare) && !is.null(sweden_compare)) {
  combined_conv <- rbind(
    italy_compare$convergence_by_profile,
    sweden_compare$convergence_by_profile
  )
  saveRDS(combined_conv, file.path(data_path, "v9", "outputs", "step10_convergence_table.rds"))
  cat("  Salvato: v9/step10_convergence_table.rds\n")
}


# ##############################################################################
# RIEPILOGO
# ##############################################################################

cat("\n============================================================\n")
cat("RIEPILOGO STEP 10 — LCA\n")
cat("============================================================\n")
cat("  Italia:\n")
cat(sprintf("    k BIC-optimal: %d\n", it_lca$fit_tab$k[which.min(it_lca$fit_tab$bic)]))
cat(sprintf("    Entropia (k=5): %.3f\n",
            it_lca$fit_tab$entropy[it_lca$fit_tab$k == 5]))
if (!is.null(italy_compare))
  cat(sprintf("    Convergenza globale k-means vs LCA(k=5): %.1f%%\n",
              italy_compare$global_convergence))
cat("\n  Svezia:\n")
cat(sprintf("    k BIC-optimal: %d\n", se_lca$fit_tab$k[which.min(se_lca$fit_tab$bic)]))
cat(sprintf("    Entropia (k=6): %.3f\n",
            se_lca$fit_tab$entropy[se_lca$fit_tab$k == 6]))
if (!is.null(sweden_compare))
  cat(sprintf("    Convergenza globale k-means vs LCA(k=6): %.1f%%\n",
              sweden_compare$global_convergence))

cat("\n  Brief di riferimento (line 186-189):\n")
cat("    BIC gomito: k=6 IT/SE | Entropia: .831 IT / .833 SE\n")
cat("    Convergenza Connected: 70% IT / 76% SE\n")
cat("    Convergenza Fragile:   51% IT / 76% SE\n")

cat("\n============================================================\n")
cat("STEP 10 COMPLETATO.\n")
cat("============================================================\n")
