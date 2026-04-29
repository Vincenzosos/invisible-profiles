# ==============================================================================
# STEP 7: K-MEANS CLUSTERING — ITALY
# Thesis: "Invisible Profiles"
# SHARE Wave 9, Italian 65+
#
# Pipeline (da brief §):
#   Part A — Diagnostics: elbow, silhouette, gap su k=2..10
#   Part B — K-means k=6 su 31 variabili originali standardizzate (Trentini)
#   Part C — Identificazione micro-cluster outlier (brief: ~35 ind. con valori
#            estremi su digit_PC3/PC4)
#   Part D — Rimozione micro-cluster, refit finale k=5
#   Part E — Mapping dei 5 cluster ai nomi canonici del brief
#   Part F — Tabella descrittiva per profilo
#   Part G — Validazione ANOVA su lifesat (post-hoc, via merge con
#            share_italy_all_approaches.rds per demographics)
#   Part H — Salvataggio
#
# Pipeline v9 (sample n = 2,378): re-fit fresco con seed per riproducibilità.
# I 5 nomi inglesi dei profili vengono mappati ai cluster emergenti per
# contenuto (Fragile Resigned, Fragile Depressed, Moderate Isolated,
# Traditional Social, Connected Active).
#
# INPUT:  v9/step2_italy_w8_std.rds            (standardizzate, per clustering)
#         v9/step2_italy_w8_clean.rds          (valori originali, per descrittive)
#         share_italy_all_approaches.rds    (demographics esterni via mergeid)
# OUTPUT: v9/step7_italy_w8_kmeans_k6.rds      (pre-micro-cluster removal)
#         v9/step7_italy_w8_kmeans_k5.rds      (finale, 5 profili)
#         v9/step7_italy_w8_with_clusters.rds  (dati + cluster + labels)
#         v9/step7_italy_w8_profile_table.rds  (tabella riassuntiva profili)
# ==============================================================================

library(dplyr)
library(cluster)     # silhouette
library(ggplot2)

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"

cat("============================================================\n")
cat("STEP 7: K-MEANS CLUSTERING — ITALY\n")
cat("============================================================\n\n")


# --- 0. LOAD DATA -----------------------------------------------------------

italy_std   <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_w8_std.rds"))
italy_clean <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_w8_clean.rds"))
suppressPackageStartupMessages(library(haven))
italy_std   <- haven::zap_labels(italy_std)
italy_clean <- haven::zap_labels(italy_clean)
cat("  Loaded step2_italy_w8_std.rds:  ", nrow(italy_std), "rows\n")
cat("  Loaded step2_italy_w8_clean.rds:", nrow(italy_clean), "rows\n\n")

# Merge demographics (lifesat, yedu, gender, isced, mstat) dal file storico
# share_italy_all_approaches.rds tramite mergeid. Queste variabili NON sono
# nel v9/ pipeline (che ha solo le 31 analitiche), quindi vengono recuperate
# post-hoc per descrittiva e validazione ANOVA.
demo_file <- file.path(data_path, "share_italy_all_approaches.rds")
demo_vars <- c("mergeid", "gender", "age", "yedu", "isced", "mstat",
               "single", "nchild", "lifesat", "lifehap")

italy_clean_enriched <- italy_clean

if (file.exists(demo_file)) {
  cat("  Loading demographic file:", basename(demo_file), "\n")
  demo_df <- readRDS(demo_file)
  # Prendi solo le vars che NON esistono già in italy_clean (evita conflitti)
  missing_demo_vars <- setdiff(demo_vars, c("mergeid", names(italy_clean)))
  cat(sprintf("  Vars da recuperare dall'approaches file: %s\n",
              paste(missing_demo_vars, collapse = ", ")))

  if (length(missing_demo_vars) > 0) {
    # Match via mergeid (più sicuro di left_join quando ci sono colonne omonime)
    idx <- match(italy_clean_enriched$mergeid, demo_df$mergeid)
    for (v in missing_demo_vars) {
      italy_clean_enriched[[v]] <- demo_df[[v]][idx]
    }
    n_matched <- sum(!is.na(idx))
    cat(sprintf("  Match su mergeid: %d/%d righe (%.1f%%)\n",
                n_matched, nrow(italy_clean_enriched),
                100 * n_matched / nrow(italy_clean_enriched)))
    if ("lifesat" %in% missing_demo_vars) {
      n_lifesat <- sum(!is.na(italy_clean_enriched$lifesat))
      cat(sprintf("  Righe con lifesat non-NA: %d (%.1f%%)\n\n",
                  n_lifesat, 100 * n_lifesat / nrow(italy_clean_enriched)))
    } else cat("\n")
  } else {
    cat("  (Tutte le vars demographics sono già in italy_clean.)\n\n")
  }
} else {
  cat("  ATTENZIONE: file demographics non trovato. Descrittiva/ANOVA parziali.\n\n")
  italy_clean_enriched$lifesat <- NA
  italy_clean_enriched$yedu    <- NA
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

# Escludi zero-variance (ac035d4, ac035d7 in Italia)
zero_var_check <- sapply(italy_std[, all_31], sd)
zero_vars      <- names(zero_var_check[zero_var_check == 0])
active_vars    <- setdiff(all_31, zero_vars)
cat("  Variabili a varianza zero escluse:",
    ifelse(length(zero_vars) > 0, paste(zero_vars, collapse = ", "), "nessuna"), "\n")
cat("  Variabili attive per clustering:", length(active_vars), "\n\n")

# Matrice dati standardizzati per clustering (n x 29)
X <- as.matrix(italy_std[, active_vars])


# ##############################################################################
# PART A: DIAGNOSTICS (elbow, silhouette, gap)
# ##############################################################################

cat("============================================================\n")
cat("PART A: DIAGNOSTICS k = 2..10\n")
cat("============================================================\n\n")

set.seed(42)

k_range <- 2:10
diag_tab <- data.frame(
  k           = integer(),
  tot_withinss = numeric(),
  between_pct  = numeric(),
  silhouette   = numeric()
)

for (k in k_range) {
  km <- kmeans(X, centers = k, nstart = 50, iter.max = 200)
  # Silhouette richiede matrice di distanze: usiamo un campione per velocità
  set.seed(42)
  idx_sample <- sample(seq_len(nrow(X)), min(1000, nrow(X)))
  sil_mean <- if (k >= 2) {
    sil <- silhouette(km$cluster[idx_sample], dist(X[idx_sample, ]))
    mean(sil[, "sil_width"])
  } else NA

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

# Elbow location: dove la riduzione relativa di tot.withinss si appiattisce
delta_wss <- c(NA, diff(diag_tab$tot_withinss))
ratio_wss <- delta_wss / diag_tab$tot_withinss[-length(diag_tab$tot_withinss)]
cat("\n  Riduzione incrementale di tot.withinss:\n")
for (i in 2:nrow(diag_tab)) {
  cat(sprintf("    k=%d→%d: Δ=%.0f (%.1f%% del wss precedente)\n",
              diag_tab$k[i-1], diag_tab$k[i],
              -delta_wss[i], -100 * ratio_wss[i-1]))
}

cat("\n  Scelta k=6 (brief): non elbow netto, silhouette privilegia k piccoli\n")
cat("  ma k=6 dà migliore interpretabilità e comparabilità cross-country.\n")
cat("  Il micro-cluster (k=6) sarà poi rimosso, lasciando 5 profili finali.\n\n")


# ##############################################################################
# PART B: K-MEANS k=6 (canonico, per identificare micro-cluster)
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
cluster_sizes_k6 <- table(km6$cluster)
for (c in seq_along(cluster_sizes_k6)) {
  cat(sprintf("    Cluster %d: %4d obs (%.1f%%)\n",
              c, cluster_sizes_k6[c], 100 * cluster_sizes_k6[c] / sum(cluster_sizes_k6)))
}
cat("\n")


# ##############################################################################
# PART C: IDENTIFICAZIONE MICRO-CLUSTER OUTLIER
# ##############################################################################

cat("============================================================\n")
cat("PART C: IDENTIFICAZIONE MICRO-CLUSTER\n")
cat("============================================================\n\n")

# Criterio (da brief §): micro-cluster = il cluster più piccolo E con valori
# estremi su variabili digitali. Verifichiamo calcolando distanza del centroide
# dal centro globale sulle dimensioni digital.
centroids_k6 <- km6$centers  # 6 x 29, già standardizzati

# Punteggi estremi dei centroidi (distanza dall'origine nello spazio z-score)
centroid_norms <- sqrt(rowSums(centroids_k6^2))
cat("  Distanza Euclidea del centroide dal centro globale (0,0,...,0):\n")
for (c in 1:6) {
  cat(sprintf("    Cluster %d (n=%d): norm=%.2f\n",
              c, cluster_sizes_k6[c], centroid_norms[c]))
}

# Per le variabili digitali (subset dei centroidi)
digital_active <- setdiff(digital_vars, zero_vars)
digital_cols <- match(digital_active, active_vars)
digital_norms <- sqrt(rowSums(centroids_k6[, digital_cols, drop = FALSE]^2))
cat("\n  Distanza Euclidea del centroide sulle SOLE variabili digitali:\n")
for (c in 1:6) {
  cat(sprintf("    Cluster %d (n=%d): digital_norm=%.2f\n",
              c, cluster_sizes_k6[c], digital_norms[c]))
}

# Criterio: micro-cluster = quello più piccolo E con distanza digitale estrema
# Regola euristica: size < 5% del totale E digital_norm > 1.5× mediana degli altri
size_pct <- 100 * cluster_sizes_k6 / sum(cluster_sizes_k6)
is_small <- size_pct < 5
digital_threshold <- 1.5 * median(digital_norms[!is_small | seq_along(digital_norms) == which.min(cluster_sizes_k6)])
is_extreme <- digital_norms > digital_threshold

micro_cluster_candidates <- which(is_small & is_extreme)

cat("\n  Criterio micro-cluster: size < 5% AND digital_norm > 1.5×median\n")
cat(sprintf("  Soglia digital_norm: %.2f\n", digital_threshold))
if (length(micro_cluster_candidates) > 0) {
  cat(sprintf("  MICRO-CLUSTER identificato: cluster %d (n=%d, digital_norm=%.2f)\n",
              micro_cluster_candidates[1],
              cluster_sizes_k6[micro_cluster_candidates[1]],
              digital_norms[micro_cluster_candidates[1]]))
  micro_id <- micro_cluster_candidates[1]
} else {
  # Fallback: prendi il più piccolo se < 3% del totale
  smallest <- which.min(cluster_sizes_k6)
  if (size_pct[smallest] < 3) {
    cat(sprintf("  Nessun cluster soddisfa entrambi i criteri. Fallback: cluster più piccolo\n"))
    cat(sprintf("  (cluster %d, n=%d, %.1f%% del totale)\n",
                smallest, cluster_sizes_k6[smallest], size_pct[smallest]))
    micro_id <- smallest
  } else {
    cat("  NESSUN micro-cluster identificato. k=6 verrà collassato a k=5 senza rimozione.\n")
    micro_id <- NA
  }
}

if (!is.na(micro_id)) {
  cat("\n  Profilo del micro-cluster (valori centroidi, top-10 più estremi):\n")
  centroid_extreme <- sort(abs(centroids_k6[micro_id, ]), decreasing = TRUE)[1:10]
  extreme_names <- names(centroid_extreme)
  for (nm in extreme_names) {
    val <- centroids_k6[micro_id, nm]
    cat(sprintf("    %-22s: %+.2f σ\n", nm, val))
  }
}


# ##############################################################################
# PART D: RIMOZIONE MICRO-CLUSTER + REFIT k=5
# ##############################################################################

cat("\n============================================================\n")
cat("PART D: RIMOZIONE MICRO-CLUSTER + REFIT k=5\n")
cat("============================================================\n\n")

if (!is.na(micro_id)) {
  keep_mask <- km6$cluster != micro_id
  n_kept    <- sum(keep_mask)
  n_removed <- sum(!keep_mask)
  cat(sprintf("  Rimossi: %d obs (cluster %d)\n", n_removed, micro_id))
  cat(sprintf("  Rimangono: %d obs\n\n", n_kept))

  X_clean <- X[keep_mask, ]
  italy_std_clean   <- italy_std[keep_mask, ]
  italy_clean_core  <- italy_clean_enriched[keep_mask, ]
} else {
  X_clean <- X
  italy_std_clean  <- italy_std
  italy_clean_core <- italy_clean_enriched
  n_kept <- nrow(X)
}

set.seed(42)
km5 <- kmeans(X_clean, centers = 5, nstart = 100, iter.max = 500)
cat("  K-means k=5 (post-micro-cluster removal):\n")
cat("    Convergenza:", ifelse(km5$iter < 500, "OK", "NON CONVERGED"),
    sprintf("(%d iterazioni)\n", km5$iter))
cat("    Between/Total SS:", sprintf("%.2f%%\n", 100 * km5$betweenss / km5$totss))

cat("\n  Dimensioni dei 5 cluster finali:\n")
cluster_sizes_k5 <- table(km5$cluster)
for (c in seq_along(cluster_sizes_k5)) {
  cat(sprintf("    Cluster %d: %4d obs (%.1f%%)\n",
              c, cluster_sizes_k5[c], 100 * cluster_sizes_k5[c] / sum(cluster_sizes_k5)))
}


# ##############################################################################
# PART E: MAPPING AI NOMI CANONICI DEL BRIEF (5 profili inglesi)
# ##############################################################################

cat("\n============================================================\n")
cat("PART E: MAPPING AI NOMI DEL BRIEF\n")
cat("============================================================\n\n")

# Riferimento brief (linee 111-117):
#   Fragile Resigned   | 80.2 anni | CASP 27.96 | Lone 6.01 | Internet 9%  | sn_size 2.21 | Yedu 6.9
#   Fragile Depressed  | 80.3 anni | CASP 30.79 | Lone 5.51 | Internet 20% | sn_size 2.66 | Yedu 7.3
#   Moderate Isolated  | 75.1 anni | CASP 34.64 | Lone 4.42 | Internet 28% | sn_size 1.45 | Yedu 8.7
#   Traditional Social | 75.4 anni | CASP 35.75 | Lone 3.95 | Internet 35% | sn_size 3.81 | Yedu 8.3
#   Connected Active   | 73.5 anni | CASP 38.70 | Lone 3.73 | Internet 84% | sn_size 2.61 | Yedu 11.6

brief_profiles <- data.frame(
  name        = c("Fragile Resigned", "Fragile Depressed", "Moderate Isolated",
                  "Traditional Social", "Connected Active"),
  age_ref     = c(80.2, 80.3, 75.1, 75.4, 73.5),
  casp_ref    = c(27.96, 30.79, 34.64, 35.75, 38.70),
  lone_ref    = c(6.01, 5.51, 4.42, 3.95, 3.73),
  internet_ref= c(0.09, 0.20, 0.28, 0.35, 0.84),
  snsize_ref  = c(2.21, 2.66, 1.45, 3.81, 2.61),
  stringsAsFactors = FALSE
)

# Calcola stats sui cluster risultanti (in ORIGINAL UNITS, NON standardizzate)
italy_clean_core$cluster_num <- km5$cluster

cluster_stats <- italy_clean_core %>%
  group_by(cluster_num) %>%
  summarise(
    n            = n(),
    age_mean     = mean(unclass(age), na.rm = TRUE),
    casp_mean    = mean(unclass(casp), na.rm = TRUE),
    lone_mean    = mean(unclass(loneliness), na.rm = TRUE),
    internet_pct = mean(unclass(internet), na.rm = TRUE),
    snsize_mean  = mean(unclass(sn_size_w9), na.rm = TRUE),
    .groups = "drop"
  )

cat("  Stats dei 5 cluster emergenti (valori originali non-standardizzati):\n")
print(as.data.frame(cluster_stats))

# Algoritmo di matching: per ogni cluster emergente, trova il profilo brief
# con distanza Euclidea minima sulle 5 dimensioni di riferimento (normalizzate).
cat("\n  Matching cluster → brief profile (distanza Euclidea su 5 metriche):\n")

# Normalizza ciascuna metrica (sia in brief che in cluster_stats) per confrontare
norm_metric <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)

brief_norm <- data.frame(
  age      = norm_metric(brief_profiles$age_ref),
  casp     = norm_metric(brief_profiles$casp_ref),
  lone     = norm_metric(brief_profiles$lone_ref),
  internet = norm_metric(brief_profiles$internet_ref),
  snsize   = norm_metric(brief_profiles$snsize_ref)
)

# Normalizza cluster_stats usando la stessa scala del brief (z-score rispetto al brief)
# Per un match robusto, usiamo le stesse medie/SD del brief:
z_by_brief <- function(x_cluster, x_brief) {
  (x_cluster - mean(x_brief, na.rm = TRUE)) / sd(x_brief, na.rm = TRUE)
}

cluster_norm <- data.frame(
  age      = z_by_brief(cluster_stats$age_mean,     brief_profiles$age_ref),
  casp     = z_by_brief(cluster_stats$casp_mean,    brief_profiles$casp_ref),
  lone     = z_by_brief(cluster_stats$lone_mean,    brief_profiles$lone_ref),
  internet = z_by_brief(cluster_stats$internet_pct, brief_profiles$internet_ref),
  snsize   = z_by_brief(cluster_stats$snsize_mean,  brief_profiles$snsize_ref)
)

# Matrice di distanze: 5 cluster x 5 brief profiles
dist_matrix <- matrix(NA, nrow = 5, ncol = 5,
                      dimnames = list(paste0("Cluster", 1:5), brief_profiles$name))
for (i in 1:5) {
  for (j in 1:5) {
    dist_matrix[i, j] <- sqrt(sum((cluster_norm[i, ] - brief_norm[j, ])^2, na.rm = TRUE))
  }
}
cat("\n  Distance matrix (cluster → brief profile):\n")
print(round(dist_matrix, 2))

# Hungarian-style assignment (greedy: il più simile prima, poi il secondo, ecc.)
# Implementazione greedy semplice per 5x5.
assignment <- rep(NA, 5)
available_brief <- rep(TRUE, 5)
for (step in 1:5) {
  # Trova la coppia (cluster, brief) con distanza minima tra quelle ancora libere
  best_dist <- Inf
  best_i <- best_j <- NA
  for (i in 1:5) {
    if (!is.na(assignment[i])) next
    for (j in 1:5) {
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

# Applica i nomi ai dati
profile_names <- brief_profiles$name[assignment]
italy_clean_core$profile <- factor(profile_names[italy_clean_core$cluster_num],
                                   levels = brief_profiles$name)

cat("\n  ASSIGNMENT FINALE:\n")
for (i in 1:5) {
  cat(sprintf("    Cluster numerico %d → %s (n=%d)\n",
              i, profile_names[i], cluster_sizes_k5[i]))
}


# ##############################################################################
# PART F: TABELLA DESCRITTIVA PER PROFILO
# ##############################################################################

cat("\n============================================================\n")
cat("PART F: TABELLA DESCRITTIVA PER PROFILO\n")
cat("============================================================\n\n")

# Variabili extra da demographics (se disponibili)
extra_vars <- c("yedu", "gender", "lifesat", "lifehap")
extra_available <- intersect(extra_vars, names(italy_clean_core))

profile_table <- italy_clean_core %>%
  group_by(profile) %>%
  summarise(
    n           = n(),
    pct         = 100 * n() / nrow(italy_clean_core),
    age         = mean(age, na.rm = TRUE),
    female_pct  = if ("gender" %in% extra_available)
                    100 * mean(gender == 2, na.rm = TRUE) else NA_real_,  # 2 = female in SHARE
    yedu        = if ("yedu" %in% extra_available)
                    mean(yedu, na.rm = TRUE) else NA_real_,
    internet    = mean(internet, na.rm = TRUE),
    casp        = mean(casp, na.rm = TRUE),
    lone        = mean(loneliness, na.rm = TRUE),
    hope_future = mean(hope_future, na.rm = TRUE),
    sn_size     = mean(sn_size_w9, na.rm = TRUE),
    lifesat     = if ("lifesat" %in% extra_available)
                    mean(lifesat, na.rm = TRUE) else NA_real_,
    adl         = mean(adl, na.rm = TRUE),
    iadl        = mean(iadl, na.rm = TRUE),
    eurod       = mean(eurod, na.rm = TRUE),
    .groups = "drop"
  )

cat("  Profile | n | % | age | %F | yedu | internet | CASP | Lone | Hope | sn_size | LifeSat | ADL | IADL | EURO-D\n")
for (i in seq_len(nrow(profile_table))) {
  p <- profile_table[i, ]
  cat(sprintf("  %-20s | %4d | %4.1f%% | %5.1f | %4.0f%% | %4.1f | %5.1f%% | %5.2f | %4.2f | %4.1f | %5.2f | %5.2f | %4.2f | %4.2f | %4.2f\n",
              p$profile, p$n, p$pct, p$age,
              p$female_pct,
              p$yedu, 100 * p$internet, p$casp, p$lone,
              100 * p$hope_future,
              p$sn_size, p$lifesat, p$adl, p$iadl, p$eurod))
}

# Confronto col brief
cat("\n  CONFRONTO CON BRIEF (brief values in parentesi):\n")
brief_ref <- data.frame(
  profile   = brief_profiles$name,
  n_brief   = c(364, 270, 646, 509, 478),
  pct_brief = c(16.1, 11.9, 28.5, 22.5, 21.1),
  age_brief = c(80.2, 80.3, 75.1, 75.4, 73.5),
  casp_brief= c(27.96, 30.79, 34.64, 35.75, 38.70)
)

profile_comparison <- profile_table %>%
  left_join(brief_ref, by = "profile")

for (i in seq_len(nrow(profile_comparison))) {
  p <- profile_comparison[i, ]
  cat(sprintf("    %-20s: n=%d (brief %d)  |  pct=%.1f%% (brief %.1f%%)  |  age=%.1f (brief %.1f)  |  CASP=%.2f (brief %.2f)\n",
              p$profile, p$n, p$n_brief, p$pct, p$pct_brief,
              p$age, p$age_brief, p$casp, p$casp_brief))
}


# ##############################################################################
# PART G: VALIDAZIONE ANOVA SU LIFESAT
# ##############################################################################

cat("\n============================================================\n")
cat("PART G: VALIDAZIONE ANOVA\n")
cat("============================================================\n\n")

if ("lifesat" %in% names(italy_clean_core) && sum(!is.na(italy_clean_core$lifesat)) > 100) {
  # ANOVA su lifesat
  aov_fit <- aov(lifesat ~ profile, data = italy_clean_core)
  aov_summary <- summary(aov_fit)
  cat("  ANOVA: lifesat ~ profile\n")
  print(aov_summary)

  f_stat <- aov_summary[[1]]["profile", "F value"]
  p_val  <- aov_summary[[1]]["profile", "Pr(>F)"]
  df_between <- aov_summary[[1]]["profile", "Df"]
  df_within  <- aov_summary[[1]]["Residuals", "Df"]

  cat(sprintf("\n  F(%d, %d) = %.2f, p = %s\n",
              df_between, df_within, f_stat, format.pval(p_val, digits = 3)))
  cat("  Brief dichiarava: F(4, 2262) = 96.66, p < 2e-16\n\n")

  # Tukey HSD per confronti a coppie
  cat("  Tukey HSD (confronti a coppie tra profili):\n")
  tukey <- TukeyHSD(aov_fit, "profile", conf.level = 0.95)
  print(tukey$profile)

  # ANOVA anche su altre variabili rilevanti (se presenti)
  extra_anova_vars <- intersect(c("casp", "loneliness", "internet", "eurod", "mobility"),
                                 names(italy_clean_core))
  cat("\n  ANOVA F-statistics per altre variabili chiave:\n")
  for (v in extra_anova_vars) {
    a <- summary(aov(italy_clean_core[[v]] ~ italy_clean_core$profile))[[1]]
    f <- a[1, "F value"]; p <- a[1, "Pr(>F)"]
    cat(sprintf("    %-15s: F(%d, %d) = %.2f, p = %s\n",
                v, a[1,"Df"], a[2,"Df"], f, format.pval(p, digits = 3)))
  }
} else {
  cat("  ATTENZIONE: lifesat non disponibile o troppe NA. ANOVA validation saltata.\n")
}


# ##############################################################################
# PART H: SALVATAGGIO
# ##############################################################################

cat("\n============================================================\n")
cat("SALVATAGGIO RISULTATI\n")
cat("============================================================\n")

# Step 7a: oggetto k-means k=6 (pre-micro-cluster removal)
kmeans_k6_results <- list(
  km_model     = km6,
  cluster_sizes = as.integer(cluster_sizes_k6),
  micro_cluster_id = micro_id,
  micro_n       = if (!is.na(micro_id)) as.integer(cluster_sizes_k6[micro_id]) else 0L,
  diagnostics   = diag_tab,
  active_vars   = active_vars,
  n_obs         = nrow(X)
)
saveRDS(kmeans_k6_results, file.path(data_path, "v9", "outputs", "step7_italy_w8_kmeans_k6.rds"))
cat("  Salvato: v9/step7_italy_w8_kmeans_k6.rds\n")

# Step 7b: oggetto k-means k=5 finale
kmeans_k5_results <- list(
  km_model       = km5,
  cluster_sizes  = as.integer(cluster_sizes_k5),
  profile_names  = profile_names,       # vettore nomi inglesi (ordine = cluster 1..5)
  assignment     = assignment,          # cluster num → brief profile index
  profile_table  = profile_table,       # descrittiva per profilo
  brief_comparison = profile_comparison,# confronto con brief
  active_vars    = active_vars,
  n_obs          = n_kept,
  n_removed_micro = if (!is.na(micro_id)) as.integer(cluster_sizes_k6[micro_id]) else 0L
)
saveRDS(kmeans_k5_results, file.path(data_path, "v9", "outputs", "step7_italy_w8_kmeans_k5.rds"))
cat("  Salvato: v9/step7_italy_w8_kmeans_k5.rds\n")

# Step 7c: dati arricchiti con cluster e profile label
italy_with_clusters <- italy_clean_core
saveRDS(italy_with_clusters, file.path(data_path, "v9", "outputs", "step7_italy_w8_with_clusters.rds"))
cat("  Salvato: v9/step7_italy_w8_with_clusters.rds\n")

# Step 7d: tabella riassuntiva profilo (solo il pezzo pubblicabile)
saveRDS(profile_table, file.path(data_path, "v9", "outputs", "step7_italy_w8_profile_table.rds"))
cat("  Salvato: v9/step7_italy_w8_profile_table.rds\n")


# ##############################################################################
# RIEPILOGO FINALE
# ##############################################################################

cat("\n============================================================\n")
cat("RIEPILOGO STEP 7 — ITALY\n")
cat("============================================================\n")
cat("  Osservazioni iniziali (step2):", nrow(italy_std), "\n")
if (!is.na(micro_id)) {
  cat("  Micro-cluster rimosso (k=6 → k=5):", cluster_sizes_k6[micro_id],
      sprintf("obs (%.1f%%)\n", 100 * cluster_sizes_k6[micro_id] / nrow(italy_std)))
}
cat("  Osservazioni finali:          ", n_kept, "\n")
cat("  Numero profili:                5\n\n")

cat("  Profili (nome → n, %):\n")
for (i in 1:5) {
  pname <- profile_names[i]
  n_i   <- cluster_sizes_k5[i]
  pct_i <- 100 * n_i / n_kept
  cat(sprintf("    %-20s: %4d (%.1f%%)\n", pname, n_i, pct_i))
}

cat("\n============================================================\n")
cat("STEP 7 COMPLETATO.\n")
cat("Prossimo step: Clustering Svezia (Step 8) o scrittura Chapter 4\n")
cat("============================================================\n")
