# ==============================================================================
# STEP 32: BINARY DOWN-WEIGHT SENSITIVITY (Trentini #2/#10, 3rd prong)
# Thesis: "Beyond the Monolith"
#
# Trentini chiede di "pesare le binarie (guarda Gower)". Questo script tiene la
# specifica deployata (K-means euclideo su variabili standardizzate) ma down-pesa
# le binarie di un fattore w<1, lasciando invariate le non-binarie, e ri-deriva
# la partizione al k deployato. ARI vs deployed misura se pesare differentemente
# le binarie altera la macro-typology.
#
# Le 11 binarie (def. in 02_listwise_outliers.R): phinact, home_own, internet,
# ac035d1, ac035d5, ac035d8, sp002_, sp008_, ac035d4, ac035d7, hope_future.
#   Italy: 9 attive (ac035d4/ac035d7 zero-variance, escluse) — k=5
#   Sweden: 11 attive — k=6
#
# INPUT (read-only):
#   v9/outputs/step2_italy_std.rds, step4_sweden_std.rds   (input matrix std)
#   v9/outputs/step7_italy_with_clusters.rds               (deployed cluster_num)
#   v9/outputs/step8_sweden_with_clusters.rds
# OUTPUT:
#   v9/outputs/sensitivities/sens5_binary_downweight.csv
#   append a v9/outputs/sensitivities/fase2_summary.txt
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(mclust)
})

data_path <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"
ip      <- file.path(data_path, "v9", "outputs")
out_dir <- file.path(ip, "sensitivities")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

cat("============================================================\n")
cat("STEP 32: BINARY DOWN-WEIGHT SENSITIVITY (#2/#10 Trentini)\n")
cat("============================================================\n\n")

# --- Variabili (identico a 02/04/06/31) ---
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

# --- Load deployed objects ---
it_std   <- readRDS(file.path(ip, "step2_italy_std.rds"))
se_std   <- readRDS(file.path(ip, "step4_sweden_std.rds"))
it_clust <- readRDS(file.path(ip, "step7_italy_with_clusters.rds"))
se_clust <- readRDS(file.path(ip, "step8_sweden_with_clusters.rds"))

dep_it <- setNames(it_clust$cluster_num, it_clust$mergeid)
dep_se <- setNames(se_clust$cluster_num, se_clust$mergeid)
dep_it_profile <- setNames(it_clust$profile, it_clust$mergeid)
dep_se_profile <- setNames(se_clust$profile, se_clust$mergeid)

it_active <- setdiff(all_31, c("ac035d4", "ac035d7"))   # 29
se_active <- all_31                                      # 31
it_bin    <- setdiff(binary_vars, c("ac035d4", "ac035d7"))  # 9 attive in IT
se_bin    <- binary_vars                                    # 11 attive in SE

cat(sprintf("Italy : %d var attive, %d binarie, k=5, n=%d\n",
            length(it_active), length(it_bin), length(dep_it)))
cat(sprintf("Sweden: %d var attive, %d binarie, k=6, n=%d\n\n",
            length(se_active), length(se_bin), length(dep_se)))

ari_via_mergeid <- function(dep, new) {
  common <- intersect(names(dep), names(new))
  if (length(common) < 10) return(NA_real_)
  mclust::adjustedRandIndex(dep[common], new[common])
}

# Down-pesa le binarie di w (std space), ri-deriva K-means agli stessi parametri
# deployati (seed=42, nstart=100). Ritorna ARI vs deployed e profile-purity
# (per-profilo dominant share, sum rowmax / n) come misura di macro-stabilità.
run_downweight <- function(std_df, active, bin, k, dep, dep_profile, w) {
  X <- as.matrix(std_df[, active])
  X[, bin] <- X[, bin] * w
  set.seed(42)
  km   <- kmeans(X, centers = k, nstart = 100, iter.max = 500)
  part <- setNames(km$cluster, std_df$mergeid)
  ari  <- ari_via_mergeid(dep, part)
  common <- intersect(names(dep_profile), names(part))
  tab    <- table(dep_profile[common], part[common])
  purity <- sum(apply(tab, 1, max)) / sum(tab)   # per-profilo dominant share
  list(ari = ari, purity = purity)
}

weights <- c(0.5, 1 / sqrt(2))

cat("--- ARI / profile-purity vs deployed per peso (w=1.0 = sanity: deve ~1.0) ---\n")
results <- data.frame()
for (w in c(1.0, weights)) {
  r_it <- run_downweight(it_std, it_active, it_bin, 5, dep_it, dep_it_profile, w)
  r_se <- run_downweight(se_std, se_active, se_bin, 6, dep_se, dep_se_profile, w)
  tag <- if (abs(w - 1/sqrt(2)) < 1e-6) "1/sqrt(2)" else sprintf("%.4f", w)
  cat(sprintf("  w=%-9s : IT ARI=%.4f purity=%.4f | SE ARI=%.4f purity=%.4f\n",
              tag, r_it$ari, r_it$purity, r_se$ari, r_se$purity))
  if (abs(w - 1.0) > 1e-9) {
    results <- rbind(
      results,
      data.frame(country = "Italy",  weight = w, n_binaries = length(it_bin),
                 ari_vs_deployed = r_it$ari, profile_purity = r_it$purity,
                 stringsAsFactors = FALSE),
      data.frame(country = "Sweden", weight = w, n_binaries = length(se_bin),
                 ari_vs_deployed = r_se$ari, profile_purity = r_se$purity,
                 stringsAsFactors = FALSE)
    )
  }
}

write.csv(results, file.path(out_dir, "sens5_binary_downweight.csv"), row.names = FALSE)
cat("\nSalvato:", file.path(out_dir, "sens5_binary_downweight.csv"), "\n")

# --- Aggiorna fase2_summary.txt con la 5a sensitivity ---
get_ari <- function(country, w) {
  results$ari_vs_deployed[results$country == country &
                            abs(results$weight - w) < 1e-6]
}
addendum <- c(
  "",
  "--------------------------------------------------------------------------------",
  "5. Binary down-weight (w=0.5 / w=1/sqrt(2)) -- Trentini #2/#10 (3rd prong)",
  "   Specifica: K-means euclideo deployato, binarie down-pesate di w (std space).",
  sprintf("   ARI vs deployed  Italy : w=0.5 %.4f / w=1/sqrt(2) %.4f",
          get_ari("Italy", 0.5),  get_ari("Italy", 1/sqrt(2))),
  sprintf("   ARI vs deployed  Sweden: w=0.5 %.4f / w=1/sqrt(2) %.4f",
          get_ari("Sweden", 0.5), get_ari("Sweden", 1/sqrt(2))),
  "   Detail CSV: sens5_binary_downweight.csv",
  "================================================================================"
)
cat(paste(addendum, collapse = "\n"), "\n",
    file = file.path(out_dir, "fase2_summary.txt"), append = TRUE)
cat("Addendum '5. Binary down-weight' aggiunto a fase2_summary.txt\n")
cat("\nDONE.\n")
