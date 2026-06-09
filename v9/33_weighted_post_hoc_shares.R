# ==============================================================================
# STEP 33: WEIGHTED POST-HOC CLUSTER SHARES (Trentini #8)
# Thesis: "Beyond the Monolith"
#
# Trentini #8 (pag. 18): "se riporti i numeri dovresti riaggiustare con gli weights".
# Calcola le cluster shares unweighted (deployed) e weighted (post-stratification con
# il design weight SHARE Wave 9) e il delta in punti percentuali. Proietta sulle
# popolazioni nazionali over-65 (Istat 2024 IT = 14.18M; Statistics Sweden 2024 ~2.06M).
#
# Weight SHARE Wave 9 (gv_weights): cciw_w9 = calibrated cross-sectional individual
# weight (stesso nome per IT e SE; la colonna `country` distingue i paesi).
#
# INPUT (read-only):
#   v9/outputs/step7_italy_with_clusters.rds   (mergeid, cluster_num, profile)
#   v9/outputs/step8_sweden_with_clusters.rds
#   _share_data/sharew9_rel9-0-0_gv_weights.dta (mergeid, cciw_w9)
# OUTPUT:
#   v9/outputs/post_hoc_weighted_shares.csv
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
})

data_path <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"
ip <- file.path(data_path, "v9", "outputs")

ITALIAN_OVER_65 <- 14180000   # Istat 2024
SWEDISH_OVER_65 <-  2060000   # Statistics Sweden 2024 (~2.06M, da prompt utente)

cat("============================================================\n")
cat("STEP 33: WEIGHTED POST-HOC CLUSTER SHARES (#8 Trentini)\n")
cat("============================================================\n\n")

# --- Load deployed cluster assignments ---
it <- readRDS(file.path(ip, "step7_italy_with_clusters.rds"))
se <- readRDS(file.path(ip, "step8_sweden_with_clusters.rds"))

# --- Load Wave 9 weights ---
wt <- read_dta(file.path(data_path, "_share_data", "sharew9_rel9-0-0_gv_weights.dta"))
wt <- wt %>%
  transmute(mergeid = as.character(mergeid),
            cciw_w9 = as.numeric(zap_labels(cciw_w9)))

WEIGHT_IT <- "cciw_w9"
WEIGHT_SE <- "cciw_w9"   # stesso weight pooled; `country` distingue IT/SE
cat(sprintf("Weight identificato  Italy : %s\n", WEIGHT_IT))
cat(sprintf("Weight identificato  Sweden: %s  (stessa variabile pooled)\n\n", WEIGHT_SE))

profile_order_it <- c("Fragile Resigned", "Fragile Depressed", "Moderate Isolated",
                      "Traditional Social", "Connected Active")
profile_order_se <- c("Fragile", "Social Decline", "Moderate",
                      "Asset Rich", "Wealthy Digital", "Connected Wealthy")

compute_shares <- function(clust_df, profile_order, country, natpop) {
  df <- clust_df %>%
    mutate(mergeid = as.character(mergeid)) %>%
    left_join(wt, by = "mergeid")

  n_total      <- nrow(df)
  n_wt_valid   <- sum(!is.na(df$cciw_w9) & df$cciw_w9 > 0)
  cat(sprintf("--- %s: n=%d, con weight valido (cciw_w9>0)=%d (%.1f%%) ---\n",
              country, n_total, n_wt_valid, 100 * n_wt_valid / n_total))

  w_total <- sum(df$cciw_w9, na.rm = TRUE)

  out <- df %>%
    group_by(profile) %>%
    summarise(n          = n(),
              w_sum      = sum(cciw_w9, na.rm = TRUE),
              .groups = "drop") %>%
    mutate(unweighted_share_pct = 100 * n / n_total,
           weighted_share_pct   = 100 * w_sum / w_total,
           delta_pp             = weighted_share_pct - unweighted_share_pct,
           weighted_M_individuals = (weighted_share_pct / 100) * natpop / 1e6,
           country = country) %>%
    arrange(match(profile, profile_order)) %>%
    select(country, profile, n, unweighted_share_pct,
           weighted_share_pct, delta_pp, weighted_M_individuals)

  # console
  cat(sprintf("  %-20s %6s %12s %12s %9s %12s\n",
              "Profile", "n", "unwt%", "wt%", "delta_pp", "wt_M"))
  for (i in seq_len(nrow(out))) {
    cat(sprintf("  %-20s %6d %11.1f%% %11.1f%% %+8.2f %10.2fM\n",
                out$profile[i], out$n[i], out$unweighted_share_pct[i],
                out$weighted_share_pct[i], out$delta_pp[i],
                out$weighted_M_individuals[i]))
  }
  max_abs_delta <- max(abs(out$delta_pp))
  cat(sprintf("  Max |delta_pp| = %.2f pp\n", max_abs_delta))
  if (max_abs_delta >= 5) {
    bad <- out$profile[which.max(abs(out$delta_pp))]
    cat(sprintf("  WARNING: substantive weight shift detected for profile %s (|delta|=%.2f pp >= 5)\n",
                bad, max_abs_delta))
  } else if (max_abs_delta <= 3) {
    cat("  OK: all |delta_pp| <= 3 pp -> unweighted defense solida.\n")
  } else {
    cat("  NOTE: max |delta_pp| tra 3 e 5 pp -> difesa tenibile ma da segnalare.\n")
  }
  cat("\n")
  out
}

res_it <- compute_shares(it, profile_order_it, "Italy",  ITALIAN_OVER_65)
res_se <- compute_shares(se, profile_order_se, "Sweden", SWEDISH_OVER_65)

results <- bind_rows(res_it, res_se)
results_csv <- results %>%
  mutate(across(c(unweighted_share_pct, weighted_share_pct, delta_pp), ~round(.x, 2)),
         weighted_M_individuals = round(weighted_M_individuals, 3))
write.csv(results_csv, file.path(ip, "post_hoc_weighted_shares.csv"), row.names = FALSE)
cat("Salvato:", file.path(ip, "post_hoc_weighted_shares.csv"), "\n")

cat(sprintf("\nMax |delta_pp| globale  Italy=%.2f  Sweden=%.2f\n",
            max(abs(res_it$delta_pp)), max(abs(res_se$delta_pp))))
cat("\nDONE.\n")
