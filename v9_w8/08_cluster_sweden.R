# ==============================================================================
# STEP 8: K-MEANS CLUSTERING — SWEDEN
# Thesis: "Invisible Profiles"
# SHARE Wave 9, Swedish 65+
#
# Pipeline (da brief §, analogo a Step 7 ma con k=6 diretto):
#   Part A — Diagnostics: k=2..10
#   Part B — K-means k=6 finale (brief: nessun micro-cluster in Svezia)
#   Part C — Mapping dei 6 cluster ai nomi canonici del brief
#   Part D — Tabella descrittiva per profilo
#   Part E — Validazione ANOVA su lifesat (estratto da sharew9 raw .dta)
#   Part F — Salvataggio
#
# DIFFERENZE vs ITALIA:
#   - k=6 diretto (brief: "In Svezia non è emerso nessun micro-cluster analogo")
#   - 6 profili nominati invece di 5:
#       Connected Wealthy, Moderate, Fragile, Social Decline, Wealthy Digital, Asset Rich
#   - Tutte 31 variabili attive (ac035d4/d7 hanno varianza in Svezia)
#   - lifesat non è nel v9/ pipeline né in un file pre-processato — estratto
#     dal raw SHARE `sharew8_rel9-0-0_ac.dta` via ac012_ per country=13 (Svezia)
#
# INPUT:  v9/step4_sweden_w8_std.rds            (standardizzate, per clustering)
#         v9/step4_sweden_w8_clean.rds          (valori originali, per descrittive)
#         sharew8_rel9-0-0_ac.dta            (ac012_ life satisfaction)
# OUTPUT: v9/step8_sweden_w8_kmeans_k6.rds      (k-means output)
#         v9/step8_sweden_w8_with_clusters.rds  (dati + cluster + labels)
#         v9/step8_sweden_w8_profile_table.rds  (tabella riassuntiva profili)
# ==============================================================================

library(dplyr)
library(cluster)     # silhouette
library(ggplot2)
# haven per leggere file .dta SHARE (raw)
if (!requireNamespace("haven", quietly = TRUE)) {
  cat("  Installing 'haven' package for .dta reading...\n")
  install.packages("haven", quiet = TRUE)
}
library(haven)

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"

cat("============================================================\n")
cat("STEP 8: K-MEANS CLUSTERING — SWEDEN\n")
cat("============================================================\n\n")


# --- 0. LOAD DATA -----------------------------------------------------------

sweden_std   <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_w8_std.rds"))
sweden_clean <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_w8_clean.rds"))
suppressPackageStartupMessages(library(haven))
sweden_std   <- haven::zap_labels(sweden_std)
sweden_clean <- haven::zap_labels(sweden_clean)
cat("  Loaded step4_sweden_w8_std.rds:  ", nrow(sweden_std),   "rows\n")
cat("  Loaded step4_sweden_w8_clean.rds:", nrow(sweden_clean), "rows\n\n")

# --- Estrazione lifesat dal raw SHARE (ac012_) ---
# ac012_ = "On a scale 0-10, how satisfied with your life overall?" (post-rev)
ac_file <- file.path(data_path, "sharew8_rel9-0-0_ac.dta")
sweden_clean_enriched <- sweden_clean

if (file.exists(ac_file)) {
  cat("  Extracting lifesat (ac012_) from SHARE raw .dta...\n")
  ac_raw <- read_dta(ac_file, col_select = c("mergeid", "country", "ac012_"))
  # country=13 = Sweden
  ac_sweden <- ac_raw %>% filter(country == 13) %>% select(mergeid, ac012_)
  # SHARE uses negative codes for missing (-1=don't know, -2=refusal, etc.)
  ac_sweden$lifesat <- ifelse(ac_sweden$ac012_ >= 0, ac_sweden$ac012_, NA)
  ac_sweden$ac012_ <- NULL
  cat(sprintf("  SHARE Svezia rows: %d, non-NA lifesat: %d\n",
              nrow(ac_sweden), sum(!is.na(ac_sweden$lifesat))))

  # Merge via mergeid
  idx <- match(sweden_clean_enriched$mergeid, ac_sweden$mergeid)
  sweden_clean_enriched$lifesat <- ac_sweden$lifesat[idx]
  n_lifesat <- sum(!is.na(sweden_clean_enriched$lifesat))
  cat(sprintf("  Merge: %d/%d righe con lifesat non-NA (%.1f%%)\n\n",
              n_lifesat, nrow(sweden_clean_enriched),
              100 * n_lifesat / nrow(sweden_clean_enriched)))
} else {
  cat("  ATTENZIONE: ac.dta non trovato. ANOVA validation salterà lifesat.\n\n")
  sweden_clean_enriched$lifesat <- NA
}

# --- Definizione variabili (31) ---
health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")
all_31       <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

# In Svezia ac035d4/ac035d7 hanno varianza (attese tutte 31)
zero_var_check <- sapply(sweden_std[, all_31], sd)
zero_vars      <- names(zero_var_check[zero_var_check == 0])
active_vars    <- setdiff(all_31, zero_vars)
cat("  Variabili a varianza zero escluse:",
    ifelse(length(zero_vars) > 0, paste(zero_vars, collapse = ", "), "nessuna"), "\n")
cat("  Variabili attive per clustering:", length(active_vars), "\n\n")

X <- as.matrix(sweden_std[, active_vars])


# ##############################################################################
# PART A: DIAGNOSTICS
# ##############################################################################

cat("============================================================\n")
cat("PART A: DIAGNOSTICS k = 2..10\n")
cat("============================================================\n\n")

set.seed(42)

k_range <- 2:10
diag_tab <- data.frame()

for (k in k_range) {
  km <- kmeans(X, centers = k, nstart = 50, iter.max = 200)
  set.seed(42)
  idx_sample <- sample(seq_len(nrow(X)), min(1000, nrow(X)))
  sil <- silhouette(km$cluster[idx_sample], dist(X[idx_sample, ]))
  sil_mean <- mean(sil[, "sil_width"])

  diag_tab <- rbind(diag_tab, data.frame(
    k           = k,
    tot_withinss = km$tot.withinss,
    between_pct  = 100 * km$betweenss / km$totss,
    silhouette   = sil_mean
  ))
}

cat("  k | tot.withinss |  between% |  silhouette\n")
cat("  ", paste(rep("-", 48), collapse = ""), "\n")
for (i in seq_len(nrow(diag_tab))) {
  cat(sprintf("  %2d | %12.0f | %8.2f%% | %11.4f\n",
              diag_tab$k[i], diag_tab$tot_withinss[i],
              diag_tab$between_pct[i], diag_tab$silhouette[i]))
}

cat("\n  Riduzione incrementale di tot.withinss:\n")
for (i in 2:nrow(diag_tab)) {
  delta <- diag_tab$tot_withinss[i-1] - diag_tab$tot_withinss[i]
  pct   <- 100 * delta / diag_tab$tot_withinss[i-1]
  cat(sprintf("    k=%d→%d: Δ=%.0f (%.1f%% del wss precedente)\n",
              diag_tab$k[i-1], diag_tab$k[i], delta, pct))
}

cat("\n  Scelta k=6 (brief): comparabilità cross-country. Nessun micro-cluster atteso.\n\n")


# ##############################################################################
# PART B: K-MEANS k=6 FINALE
# ##############################################################################

cat("============================================================\n")
cat("PART B: K-MEANS k=6\n")
cat("============================================================\n\n")

set.seed(42)
km6 <- kmeans(X, centers = 6, nstart = 100, iter.max = 500)
cat("  Convergenza:", ifelse(km6$iter < 500, "OK", "NON CONVERGED"),
    sprintf("(%d iterazioni)\n", km6$iter))
cat("  Between/Total SS:", sprintf("%.2f%%\n", 100 * km6$betweenss / km6$totss))
cat("  Totale within SS:", round(km6$tot.withinss, 2), "\n\n")

cat("  Dimensioni dei 6 cluster:\n")
cluster_sizes <- table(km6$cluster)
for (c in seq_along(cluster_sizes)) {
  cat(sprintf("    Cluster %d: %4d obs (%.1f%%)\n",
              c, cluster_sizes[c], 100 * cluster_sizes[c] / sum(cluster_sizes)))
}

# Micro-cluster check (per coerenza col Step 7, ma atteso NONE per Svezia)
size_pct <- 100 * cluster_sizes / sum(cluster_sizes)
if (any(size_pct < 3)) {
  tiny_id <- which(size_pct < 3)
  cat(sprintf("\n  ATTENZIONE: cluster %d è < 3%% del totale. Brief dichiarava\n",
              tiny_id[1]))
  cat("  che in Svezia non emerge micro-cluster. Verificare se tenerlo o rimuovere.\n")
} else {
  cat("\n  Nessun cluster < 3% del totale → coerente col brief (no micro-cluster in SE).\n")
}


# ##############################################################################
# PART C: MAPPING AI NOMI CANONICI DEL BRIEF (6 profili)
# ##############################################################################

cat("\n============================================================\n")
cat("PART C: MAPPING AI NOMI DEL BRIEF\n")
cat("============================================================\n\n")

# Riferimento brief (linee 123-128):
#   Connected Wealthy | 72.7 | 52% | 94% | 43.91 | 3.82
#   Moderate          | 75.7 | 59% | 60% | 40.92 | 3.52
#   Fragile           | 81.9 | 69% | 22% | 33.25 | 2.85
#   Social Decline    | 78.7 | 69% | 36% | 38.76 | 3.73
#   Wealthy Digital   | 74.3 | 50% | 76% | 41.50 | 3.54
#   Asset Rich        | 74.1 | 56% | 65% | 40.37 | 2.89

brief_profiles <- data.frame(
  name        = c("Connected Wealthy", "Moderate", "Fragile",
                  "Social Decline", "Wealthy Digital", "Asset Rich"),
  age_ref     = c(72.7, 75.7, 81.9, 78.7, 74.3, 74.1),
  casp_ref    = c(43.91, 40.92, 33.25, 38.76, 41.50, 40.37),
  internet_ref= c(0.94, 0.60, 0.22, 0.36, 0.76, 0.65),
  snsize_ref  = c(3.82, 3.52, 2.85, 3.73, 3.54, 2.89),
  stringsAsFactors = FALSE
)
# Sweden brief non riporta lone/hope per ogni profilo, usiamo age/casp/internet/snsize

sweden_clean_enriched$cluster_num <- km6$cluster

cluster_stats <- sweden_clean_enriched %>%
  group_by(cluster_num) %>%
  summarise(
    n            = n(),
    age_mean     = mean(age, na.rm = TRUE),
    casp_mean    = mean(casp, na.rm = TRUE),
    internet_pct = mean(internet, na.rm = TRUE),
    snsize_mean  = mean(sn_size_w9, na.rm = TRUE),
    .groups = "drop"
  )

cat("  Stats dei 6 cluster emergenti (valori originali):\n")
print(as.data.frame(cluster_stats))

# Matching: distanza Euclidea su 4 metriche z-scored rispetto al brief
z_by_brief <- function(x_cluster, x_brief) {
  (x_cluster - mean(x_brief)) / sd(x_brief)
}

brief_norm <- data.frame(
  age      = (brief_profiles$age_ref      - mean(brief_profiles$age_ref))      / sd(brief_profiles$age_ref),
  casp     = (brief_profiles$casp_ref     - mean(brief_profiles$casp_ref))     / sd(brief_profiles$casp_ref),
  internet = (brief_profiles$internet_ref - mean(brief_profiles$internet_ref)) / sd(brief_profiles$internet_ref),
  snsize   = (brief_profiles$snsize_ref   - mean(brief_profiles$snsize_ref))   / sd(brief_profiles$snsize_ref)
)

cluster_norm <- data.frame(
  age      = z_by_brief(cluster_stats$age_mean,     brief_profiles$age_ref),
  casp     = z_by_brief(cluster_stats$casp_mean,    brief_profiles$casp_ref),
  internet = z_by_brief(cluster_stats$internet_pct, brief_profiles$internet_ref),
  snsize   = z_by_brief(cluster_stats$snsize_mean,  brief_profiles$snsize_ref)
)

dist_matrix <- matrix(NA, nrow = 6, ncol = 6,
                      dimnames = list(paste0("Cluster", 1:6), brief_profiles$name))
for (i in 1:6) {
  for (j in 1:6) {
    dist_matrix[i, j] <- sqrt(sum((cluster_norm[i, ] - brief_norm[j, ])^2, na.rm = TRUE))
  }
}
cat("\n  Distance matrix (cluster → brief profile):\n")
print(round(dist_matrix, 2))

# Greedy assignment
assignment <- rep(NA, 6)
available_brief <- rep(TRUE, 6)
cat("\n  Matching greedy (più simile prima):\n")
for (step in 1:6) {
  best_dist <- Inf
  best_i <- best_j <- NA
  for (i in 1:6) {
    if (!is.na(assignment[i])) next
    for (j in 1:6) {
      if (!available_brief[j]) next
      if (dist_matrix[i, j] < best_dist) {
        best_dist <- dist_matrix[i, j]
        best_i <- i
        best_j <- j
      }
    }
  }
  assignment[best_i] <- best_j
  available_brief[best_j] <- FALSE
  cat(sprintf("    Step %d: Cluster %d → %s (dist=%.2f)\n",
              step, best_i, brief_profiles$name[best_j], best_dist))
}

profile_names <- brief_profiles$name[assignment]
sweden_clean_enriched$profile <- factor(profile_names[sweden_clean_enriched$cluster_num],
                                        levels = brief_profiles$name)

cat("\n  ASSIGNMENT FINALE:\n")
for (i in 1:6) {
  cat(sprintf("    Cluster numerico %d → %s (n=%d)\n",
              i, profile_names[i], cluster_sizes[i]))
}


# ##############################################################################
# PART D: TABELLA DESCRITTIVA PER PROFILO
# ##############################################################################

cat("\n============================================================\n")
cat("PART D: TABELLA DESCRITTIVA PER PROFILO\n")
cat("============================================================\n\n")

has_lifesat <- "lifesat" %in% names(sweden_clean_enriched) &&
  sum(!is.na(sweden_clean_enriched$lifesat)) > 100

profile_table <- sweden_clean_enriched %>%
  group_by(profile) %>%
  summarise(
    n           = n(),
    pct         = 100 * n() / nrow(sweden_clean_enriched),
    age         = mean(age, na.rm = TRUE),
    female_pct  = 100 * mean(gender == 2, na.rm = TRUE),
    internet    = mean(internet, na.rm = TRUE),
    casp        = mean(casp, na.rm = TRUE),
    lone        = mean(loneliness, na.rm = TRUE),
    hope_future = mean(hope_future, na.rm = TRUE),
    sn_size     = mean(sn_size_w9, na.rm = TRUE),
    lifesat     = if (has_lifesat) mean(lifesat, na.rm = TRUE) else NA_real_,
    adl         = mean(adl, na.rm = TRUE),
    iadl        = mean(iadl, na.rm = TRUE),
    eurod       = mean(eurod, na.rm = TRUE),
    .groups = "drop"
  )

cat("  Profile | n | % | age | %F | internet | CASP | Lone | Hope | sn_size | LifeSat | ADL | IADL | EURO-D\n")
for (i in seq_len(nrow(profile_table))) {
  p <- profile_table[i, ]
  cat(sprintf("  %-20s | %4d | %4.1f%% | %5.1f | %4.0f%% | %5.1f%% | %5.2f | %4.2f | %4.1f | %5.2f | %5.2f | %4.2f | %4.2f | %4.2f\n",
              p$profile, p$n, p$pct, p$age,
              p$female_pct,
              100 * p$internet, p$casp, p$lone, 100 * p$hope_future,
              p$sn_size, p$lifesat, p$adl, p$iadl, p$eurod))
}

# Confronto col brief
cat("\n  CONFRONTO CON BRIEF:\n")
brief_ref <- data.frame(
  profile   = brief_profiles$name,
  n_brief   = c(384, 428, 252, 342, 155, 395),
  pct_brief = c(19.6, 21.9, 12.9, 17.5, 7.9, 20.2),
  age_brief = brief_profiles$age_ref,
  casp_brief= brief_profiles$casp_ref,
  internet_brief = brief_profiles$internet_ref,
  snsize_brief   = brief_profiles$snsize_ref
)

profile_comparison <- profile_table %>% left_join(brief_ref, by = "profile")
for (i in seq_len(nrow(profile_comparison))) {
  p <- profile_comparison[i, ]
  cat(sprintf("    %-20s: n=%d (brief %d) | pct=%.1f%% (brief %.1f%%) | age=%.1f (brief %.1f) | CASP=%.2f (brief %.2f) | internet=%.0f%% (brief %.0f%%) | sn=%.2f (brief %.2f)\n",
              p$profile, p$n, p$n_brief, p$pct, p$pct_brief,
              p$age, p$age_brief, p$casp, p$casp_brief,
              100 * p$internet, 100 * p$internet_brief,
              p$sn_size, p$snsize_brief))
}


# ##############################################################################
# PART E: VALIDAZIONE ANOVA
# ##############################################################################

cat("\n============================================================\n")
cat("PART E: VALIDAZIONE ANOVA\n")
cat("============================================================\n\n")

if (has_lifesat) {
  aov_fit <- aov(lifesat ~ profile, data = sweden_clean_enriched)
  aov_summary <- summary(aov_fit)
  cat("  ANOVA: lifesat ~ profile\n")
  print(aov_summary)

  f_stat <- aov_summary[[1]]["profile", "F value"]
  p_val  <- aov_summary[[1]]["profile", "Pr(>F)"]
  df_b   <- aov_summary[[1]]["profile",   "Df"]
  df_w   <- aov_summary[[1]]["Residuals", "Df"]
  cat(sprintf("\n  F(%d, %d) = %.2f, p = %s\n",
              df_b, df_w, f_stat, format.pval(p_val, digits = 3)))
  cat("  Brief dichiarava: F(5, 1950) = 51.39, p < 2e-16\n\n")

  cat("  Tukey HSD (top 10 confronti per magnitudo):\n")
  tukey <- TukeyHSD(aov_fit, "profile", conf.level = 0.95)
  tk_df <- as.data.frame(tukey$profile)
  tk_df <- tk_df[order(-abs(tk_df$diff)), ]
  print(head(tk_df, 10))
} else {
  cat("  lifesat non disponibile — ANOVA su lifesat saltata.\n")
}

# ANOVA su variabili chiave (sempre eseguita, non richiede lifesat)
cat("\n  ANOVA F-statistics per variabili chiave:\n")
for (v in c("casp", "loneliness", "internet", "eurod", "mobility", "sn_size_w9")) {
  if (v %in% names(sweden_clean_enriched)) {
    a <- summary(aov(sweden_clean_enriched[[v]] ~ sweden_clean_enriched$profile))[[1]]
    cat(sprintf("    %-15s: F(%d, %d) = %.2f, p = %s\n",
                v, a[1,"Df"], a[2,"Df"], a[1,"F value"],
                format.pval(a[1,"Pr(>F)"], digits = 3)))
  }
}


# ##############################################################################
# PART F: SALVATAGGIO
# ##############################################################################

cat("\n============================================================\n")
cat("SALVATAGGIO RISULTATI\n")
cat("============================================================\n")

kmeans_k6_results <- list(
  km_model         = km6,
  cluster_sizes    = as.integer(cluster_sizes),
  profile_names    = profile_names,
  assignment       = assignment,
  profile_table    = profile_table,
  brief_comparison = profile_comparison,
  diagnostics      = diag_tab,
  active_vars      = active_vars,
  n_obs            = nrow(X)
)
saveRDS(kmeans_k6_results, file.path(data_path, "v9", "outputs", "step8_sweden_w8_kmeans_k6.rds"))
cat("  Salvato: v9/step8_sweden_w8_kmeans_k6.rds\n")

saveRDS(sweden_clean_enriched, file.path(data_path, "v9", "outputs", "step8_sweden_w8_with_clusters.rds"))
cat("  Salvato: v9/step8_sweden_w8_with_clusters.rds\n")

saveRDS(profile_table, file.path(data_path, "v9", "outputs", "step8_sweden_w8_profile_table.rds"))
cat("  Salvato: v9/step8_sweden_w8_profile_table.rds\n")


# ##############################################################################
# RIEPILOGO
# ##############################################################################

cat("\n============================================================\n")
cat("RIEPILOGO STEP 8 — SWEDEN\n")
cat("============================================================\n")
cat("  Osservazioni:          ", nrow(sweden_std), "\n")
cat("  Numero profili:         6\n\n")

cat("  Profili (nome → n, %):\n")
for (i in 1:6) {
  cat(sprintf("    %-20s: %4d (%.1f%%)\n",
              profile_names[i], cluster_sizes[i],
              100 * cluster_sizes[i] / sum(cluster_sizes)))
}

cat("\n============================================================\n")
cat("STEP 8 COMPLETATO.\n")
cat("Prossimo step: Cross-country analysis / LCA / scrittura tesi\n")
cat("============================================================\n")
