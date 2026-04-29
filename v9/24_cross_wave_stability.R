# ==============================================================================
# 24_cross_wave_stability.R
# Stabilità delle partizioni K-means tra SHARE Wave 8 (2019-2020, pre-COVID)
# e Wave 9 (2021-2022, post-COVID). Italia (k=5) + Svezia (k=6).
#
# Output: v9/outputs/cross_wave_stability.json
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(mclust)
  library(clue)
  library(jsonlite)
  library(haven)
})

set.seed(42)

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
out_dir   <- file.path(data_path, "v9", "outputs")

# --- 0. INPUT CHECKS ---------------------------------------------------------

required <- c(
  "step7_italy_kmeans_k5.rds",        "step7_italy_with_clusters.rds",
  "step8_sweden_kmeans_k6.rds",       "step8_sweden_with_clusters.rds",
  "step7_italy_w8_kmeans_k5.rds",     "step7_italy_w8_with_clusters.rds",
  "step8_sweden_w8_kmeans_k6.rds",    "step8_sweden_w8_with_clusters.rds"
)
missing <- required[!file.exists(file.path(out_dir, required))]
if (length(missing) > 0) {
  stop("Missing input RDS:\n  ", paste(missing, collapse = "\n  "))
}
cat("All 8 input RDS present. OK.\n\n")

# --- 1. LOAD ------------------------------------------------------------------

read_rds_zap <- function(name) {
  x <- readRDS(file.path(out_dir, name))
  if (is.data.frame(x)) haven::zap_labels(x) else x
}

it_w9_km   <- read_rds_zap("step7_italy_kmeans_k5.rds")
it_w9_df   <- read_rds_zap("step7_italy_with_clusters.rds")
it_w8_km   <- read_rds_zap("step7_italy_w8_kmeans_k5.rds")
it_w8_df   <- read_rds_zap("step7_italy_w8_with_clusters.rds")

se_w9_km   <- read_rds_zap("step8_sweden_kmeans_k6.rds")
se_w9_df   <- read_rds_zap("step8_sweden_with_clusters.rds")
se_w8_km   <- read_rds_zap("step8_sweden_w8_kmeans_k6.rds")
se_w8_df   <- read_rds_zap("step8_sweden_w8_with_clusters.rds")

# --- 2. PANEL ARI -------------------------------------------------------------

bootstrap_ari <- function(panel_df, B = 2000, seed = 42) {
  set.seed(seed)
  ids  <- seq_len(nrow(panel_df))
  reps <- replicate(B, {
    s <- sample(ids, length(ids), replace = TRUE)
    mclust::adjustedRandIndex(panel_df$profile_w8[s], panel_df$profile_w9[s])
  })
  list(
    point = mclust::adjustedRandIndex(panel_df$profile_w8, panel_df$profile_w9),
    ci_low  = unname(quantile(reps, 0.025)),
    ci_high = unname(quantile(reps, 0.975))
  )
}

build_panel <- function(w8_df, w9_df) {
  inner_join(
    w8_df %>% transmute(mergeid = as.character(mergeid),
                        profile_w8 = as.character(profile)),
    w9_df %>% transmute(mergeid = as.character(mergeid),
                        profile_w9 = as.character(profile)),
    by = "mergeid"
  )
}

panel_it <- build_panel(it_w8_df, it_w9_df)
panel_se <- build_panel(se_w8_df, se_w9_df)

cat("Panel n - Italy:  ", nrow(panel_it), "\n")
cat("Panel n - Sweden: ", nrow(panel_se), "\n\n")

if (nrow(panel_it) < 200) stop("STOP: Italy panel n < 200")
if (nrow(panel_se) < 200) stop("STOP: Sweden panel n < 200")

ari_it <- bootstrap_ari(panel_it)
ari_se <- bootstrap_ari(panel_se)

cat(sprintf("Italy   ARI = %.4f  [%.4f, %.4f]\n",
            ari_it$point, ari_it$ci_low, ari_it$ci_high))
cat(sprintf("Sweden  ARI = %.4f  [%.4f, %.4f]\n\n",
            ari_se$point, ari_se$ci_low, ari_se$ci_high))

# --- 3. CONFUSION MATRICES ON PANEL ------------------------------------------

confusion_pcts <- function(panel_df, levels_w8, levels_w9) {
  m <- table(
    factor(panel_df$profile_w8, levels = levels_w8),
    factor(panel_df$profile_w9, levels = levels_w9)
  )
  list(
    counts  = unclass(m),
    pct_row = round(100 * sweep(unclass(m), 1, pmax(rowSums(m), 1), "/"), 1),
    pct_col = round(100 * sweep(unclass(m), 2, pmax(colSums(m), 1), "/"), 1)
  )
}

# Establish ordered profile lists (W9 names — used as canonical for matching)
levels_it_w9 <- sort(unique(as.character(it_w9_df$profile)))
levels_it_w8 <- sort(unique(as.character(it_w8_df$profile)))
levels_se_w9 <- sort(unique(as.character(se_w9_df$profile)))
levels_se_w8 <- sort(unique(as.character(se_w8_df$profile)))

conf_it <- confusion_pcts(panel_it, levels_it_w8, levels_it_w9)
conf_se <- confusion_pcts(panel_se, levels_se_w8, levels_se_w9)

cat("=== Italy panel confusion (counts) ===\n"); print(conf_it$counts); cat("\n")
cat("=== Sweden panel confusion (counts) ===\n"); print(conf_se$counts); cat("\n")

# Top-2 transitions
top_transitions <- function(panel_df) {
  panel_df %>%
    dplyr::count(profile_w8, profile_w9, name = "n") %>%
    arrange(desc(n)) %>%
    slice_head(n = 2)
}
cat("Italy top-2 transitions W8->W9:\n");  print(top_transitions(panel_it))
cat("\nSweden top-2 transitions W8->W9:\n"); print(top_transitions(panel_se))
cat("\n")

# --- 4. HUNGARIAN-MATCHED CENTROID DISTANCE ----------------------------------

hungarian_match <- function(km_w8, km_w9, df_w8, df_w9, name = "country") {
  cent_w8 <- km_w8$km_model$centers
  cent_w9 <- km_w9$km_model$centers
  common  <- intersect(colnames(cent_w8), colnames(cent_w9))
  if (length(common) < 20) {
    stop(sprintf("STOP: only %d common variables for %s (need >= 20)", length(common), name))
  }

  # Re-label centroid rows with profile names. profile_names is an unnamed
  # positional character vector: profile_names[cluster_num] = profile name.
  # Centers are stored in cluster_num=1..k row order.
  rownames(cent_w8) <- km_w8$profile_names[as.integer(rownames(cent_w8))]
  rownames(cent_w9) <- km_w9$profile_names[as.integer(rownames(cent_w9))]

  cent_w8 <- cent_w8[, common, drop = FALSE]
  cent_w9 <- cent_w9[, common, drop = FALSE]

  # Distance matrix: rows = W8 profiles, cols = W9 profiles
  dist_mat <- matrix(NA_real_,
                     nrow = nrow(cent_w8), ncol = nrow(cent_w9),
                     dimnames = list(rownames(cent_w8), rownames(cent_w9)))
  for (i in seq_len(nrow(cent_w8))) {
    for (j in seq_len(nrow(cent_w9))) {
      dist_mat[i, j] <- sqrt(sum((cent_w8[i, ] - cent_w9[j, ])^2))
    }
  }

  # Hungarian on a SQUARE matrix. Pad with large values if dimensions differ.
  pad <- max(nrow(dist_mat), ncol(dist_mat))
  big <- 1e6
  square <- matrix(big, pad, pad)
  square[seq_len(nrow(dist_mat)), seq_len(ncol(dist_mat))] <- dist_mat

  assignment <- as.integer(clue::solve_LSAP(square, maximum = FALSE))

  # Sizes from with_clusters.rds
  n_w8 <- nrow(df_w8); n_w9 <- nrow(df_w9)
  size_w8 <- table(as.character(df_w8$profile))
  size_w9 <- table(as.character(df_w9$profile))

  results <- list()
  for (i in seq_len(nrow(dist_mat))) {
    j <- assignment[i]
    if (j > ncol(dist_mat)) next  # padded slot
    p8 <- rownames(dist_mat)[i]
    p9 <- colnames(dist_mat)[j]
    s8 <- 100 * unname(size_w8[p8]) / n_w8
    s9 <- 100 * unname(size_w9[p9]) / n_w9
    results[[length(results) + 1]] <- list(
      profile_w8 = p8,
      profile_w9 = p9,
      centroid_distance = round(dist_mat[i, j], 4),
      share_w8_pct      = round(s8, 1),
      share_w9_pct      = round(s9, 1),
      delta_share_pp    = round(s9 - s8, 1),
      match_consistent_with_naming = identical(p8, p9)
    )
  }

  list(matches = results, dist_mat = dist_mat, common_vars = common)
}

cat("=== Italy: Hungarian centroid match ===\n")
m_it <- hungarian_match(it_w8_km, it_w9_km, it_w8_df, it_w9_df, "Italy")
cat("Common standardized vars:", length(m_it$common_vars), "\n\n")
print(round(m_it$dist_mat, 3))
cat("\nMatching:\n")
for (m in m_it$matches) {
  flag <- if (m$match_consistent_with_naming) "OK " else "MISMATCH"
  cat(sprintf("  %s %-20s -> %-20s  d=%.3f  share W8=%.1f%%  W9=%.1f%%  delta=%+.1fpp\n",
              flag, m$profile_w8, m$profile_w9, m$centroid_distance,
              m$share_w8_pct, m$share_w9_pct, m$delta_share_pp))
}

cat("\n=== Sweden: Hungarian centroid match ===\n")
m_se <- hungarian_match(se_w8_km, se_w9_km, se_w8_df, se_w9_df, "Sweden")
cat("Common standardized vars:", length(m_se$common_vars), "\n\n")
print(round(m_se$dist_mat, 3))
cat("\nMatching:\n")
for (m in m_se$matches) {
  flag <- if (m$match_consistent_with_naming) "OK " else "MISMATCH"
  cat(sprintf("  %s %-20s -> %-20s  d=%.3f  share W8=%.1f%%  W9=%.1f%%  delta=%+.1fpp\n",
              flag, m$profile_w8, m$profile_w9, m$centroid_distance,
              m$share_w8_pct, m$share_w9_pct, m$delta_share_pp))
}

# Sanity check
n_inconsistent_it <- sum(!sapply(m_it$matches, function(x) x$match_consistent_with_naming))
n_inconsistent_se <- sum(!sapply(m_se$matches, function(x) x$match_consistent_with_naming))
cat(sprintf("\nMatching consistency - Italy:  %d inconsistencies\n", n_inconsistent_it))
cat(sprintf("Matching consistency - Sweden: %d inconsistencies\n", n_inconsistent_se))
if (n_inconsistent_it > 1 || n_inconsistent_se > 1) {
  cat("WARNING: more than 1 profile mismatched between Hungarian and naming.\n")
  cat("         Inspect distance matrices above.\n\n")
}

# --- 5. BUILD JSON OUTPUT ----------------------------------------------------

confusion_to_list <- function(mat) {
  rn <- rownames(mat); cn <- colnames(mat)
  lapply(seq_len(nrow(mat)), function(i) {
    row_vals <- as.list(mat[i, ])
    names(row_vals) <- cn
    c(list(profile_w8 = rn[i]), row_vals)
  })
}

result <- list(
  meta = list(
    method = "Panel ARI on W8 cap W9 mergeid intersection + Hungarian-matched centroid distance on common standardized variables.",
    bootstrap = "2000 replicates, percentile CI 95%, seed=42",
    w8_period = "2019-2020 (pre-COVID)",
    w9_period = "2021-2022 (post-COVID)",
    common_vars_italy  = m_it$common_vars,
    common_vars_sweden = m_se$common_vars
  ),
  italy = list(
    panel_n  = nrow(panel_it),
    n_w8     = nrow(it_w8_df),
    n_w9     = nrow(it_w9_df),
    ari      = round(ari_it$point, 4),
    ari_ci_low  = round(ari_it$ci_low,  4),
    ari_ci_high = round(ari_it$ci_high, 4),
    structural_match     = m_it$matches,
    confusion_panel_pct_row = confusion_to_list(conf_it$pct_row),
    confusion_panel_pct_col = confusion_to_list(conf_it$pct_col)
  ),
  sweden = list(
    panel_n  = nrow(panel_se),
    n_w8     = nrow(se_w8_df),
    n_w9     = nrow(se_w9_df),
    ari      = round(ari_se$point, 4),
    ari_ci_low  = round(ari_se$ci_low,  4),
    ari_ci_high = round(ari_se$ci_high, 4),
    structural_match     = m_se$matches,
    confusion_panel_pct_row = confusion_to_list(conf_se$pct_row),
    confusion_panel_pct_col = confusion_to_list(conf_se$pct_col)
  ),
  interpretation_thresholds = list(
    ari_substantial = 0.40,
    ari_moderate    = 0.20
  )
)

json_path <- file.path(out_dir, "cross_wave_stability.json")
write(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE), json_path)
cat(sprintf("\nWrote: %s\n", json_path))

# --- 6. CONSOLE SUMMARY ------------------------------------------------------

cat("\n========== CROSS-WAVE STABILITY SUMMARY ==========\n")
cat(sprintf("ITALY  | panel n=%d | ARI=%.3f [%.3f, %.3f] | matches consistent: %d/%d\n",
            nrow(panel_it), ari_it$point, ari_it$ci_low, ari_it$ci_high,
            length(m_it$matches) - n_inconsistent_it, length(m_it$matches)))
cat(sprintf("SWEDEN | panel n=%d | ARI=%.3f [%.3f, %.3f] | matches consistent: %d/%d\n",
            nrow(panel_se), ari_se$point, ari_se$ci_low, ari_se$ci_high,
            length(m_se$matches) - n_inconsistent_se, length(m_se$matches)))
cat("===================================================\n")
