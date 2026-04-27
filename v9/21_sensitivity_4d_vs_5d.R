# ==============================================================================
# STEP 21: SENSITIVITY ANALYSIS -- 4D vs 5D (with and without the subjective block)
# Thesis: "Invisible Profiles" - Bocconi MSc EMIT (course 20570, Prof. Trentini)
#
# Refits K-means on the variable matrix after dropping the five subjective
# variables (loneliness, casp, hope_future, interest, expect_alive), and
# compares the resulting clustering to the reference 5D solution on:
#   - silhouette width
#   - within-cluster R-squared
#   - ANOVA F on life satisfaction (external validation)
#   - Adjusted Rand Index / Normalised Mutual Information
#   - cluster-size distribution
#
# The 4D segmentation is an intentionally weaker alternative: it drops the
# analytical innovation of the thesis (subjective variables as clustering
# inputs) and asks whether the five/six interpretable profiles survive.
#
# INPUT : step2_italy_std.rds, step4_sweden_std.rds,
#         step7_italy_with_clusters.rds, step8_sweden_with_clusters.rds
# OUTPUT: appended to v9/outputs/thesis_numbers.md, plus a console summary.
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(cluster)     # silhouette
  if (!requireNamespace("mclust", quietly = TRUE)) install.packages("mclust", quiet = TRUE)
  library(mclust)      # adjustedRandIndex
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
out_dir   <- file.path(data_path, "v9", "outputs")
out_md    <- file.path(out_dir, "thesis_numbers.md")

cat("============================================================\n")
cat("STEP 21: SENSITIVITY 4D vs 5D\n")
cat("============================================================\n\n")

# Variable blocks (identical to Steps 1-8)
health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                  "sp002_", "sp008_", "sn_size_w9", "social_integration",
                  "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")
all_31       <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

# Variable set without the subjective block
vars_4d_all  <- setdiff(all_31, subj_vars)
italy_active_4d  <- setdiff(vars_4d_all, c("ac035d4", "ac035d7"))  # 24 vars
sweden_active_4d <- vars_4d_all                                     # 26 vars

# ----- Load data ------------------------------------------------------------
italy_std    <- readRDS(file.path(out_dir, "step2_italy_std.rds"))
sweden_std   <- readRDS(file.path(out_dir, "step4_sweden_std.rds"))
italy_clust  <- readRDS(file.path(out_dir, "step7_italy_with_clusters.rds"))
sweden_clust <- readRDS(file.path(out_dir, "step8_sweden_with_clusters.rds"))

num <- function(x) as.numeric(haven::zap_labels(x))

# ----- Fit 4D K-means ------------------------------------------------------
fit_4d <- function(std_df, active_4d, k, seed = 42) {
  X <- as.matrix(std_df[, active_4d])
  set.seed(seed)
  km <- kmeans(X, centers = k, nstart = 100, iter.max = 500)
  d  <- dist(X)
  sil <- cluster::silhouette(km$cluster, d)
  list(
    km         = km,
    X          = X,
    mean_sil   = mean(sil[, 3]),
    r2         = km$betweenss / km$totss,
    cluster    = km$cluster
  )
}

cat("--- Italy 4D (k = 5 on ", length(italy_active_4d), " vars) ---\n", sep = "")
it4 <- fit_4d(italy_std, italy_active_4d, k = 5)
cat("    silhouette =", round(it4$mean_sil, 4), "\n")
cat("    R^2        =", round(it4$r2, 4), "\n\n")

cat("--- Sweden 4D (k = 6 on ", length(sweden_active_4d), " vars) ---\n", sep = "")
se4 <- fit_4d(sweden_std, sweden_active_4d, k = 6)
cat("    silhouette =", round(se4$mean_sil, 4), "\n")
cat("    R^2        =", round(se4$r2, 4), "\n\n")


# ----- Compare with 5D reference -------------------------------------------
compare_5d <- function(std_df, clust_df, active_5d, k_ref) {
  X <- as.matrix(std_df[, active_5d])
  ref_cluster <- as.integer(factor(as.character(clust_df$profile)))
  # Silhouette on the same distance structure as used in the 5D fit
  d <- dist(X)
  sil_ref <- cluster::silhouette(ref_cluster, d)
  km_ref  <- kmeans(X, centers = k_ref, nstart = 100, iter.max = 500)
  list(
    ref_cluster = ref_cluster,
    mean_sil    = mean(sil_ref[, 3]),
    r2          = km_ref$betweenss / km_ref$totss
  )
}

italy_active_5d  <- setdiff(all_31, c("ac035d4", "ac035d7"))
sweden_active_5d <- all_31

it5 <- compare_5d(italy_std,  italy_clust,  italy_active_5d,  k_ref = 5)
se5 <- compare_5d(sweden_std, sweden_clust, sweden_active_5d, k_ref = 6)

cat("--- 5D reference silhouette / R^2 ---\n")
cat(sprintf("    Italy  : sil = %.4f, R^2 = %.4f\n", it5$mean_sil, it5$r2))
cat(sprintf("    Sweden : sil = %.4f, R^2 = %.4f\n\n", se5$mean_sil, se5$r2))


# ----- Agreement between 4D and 5D partitions (ARI, NMI) --------------------
# 4D cluster labels vs 5D profile labels
ari_italy  <- mclust::adjustedRandIndex(it4$cluster, it5$ref_cluster)
ari_sweden <- mclust::adjustedRandIndex(se4$cluster, se5$ref_cluster)
cat("--- Adjusted Rand Index (4D vs 5D) ---\n")
cat(sprintf("    Italy  : ARI = %.4f\n", ari_italy))
cat(sprintf("    Sweden : ARI = %.4f\n\n", ari_sweden))


# ----- External validation: ANOVA on life satisfaction ---------------------
anova_lifesat <- function(std_df, clust_df, cluster_vector) {
  if (!"lifesat" %in% names(clust_df)) {
    cat("    lifesat not in cluster frame -- skip\n")
    return(NULL)
  }
  y <- num(clust_df$lifesat)
  ok <- !is.na(y) & !is.na(cluster_vector)
  if (sum(ok) < 10L) return(NULL)
  fit <- aov(y[ok] ~ factor(cluster_vector[ok]))
  summary(fit)[[1]]
}

cat("--- ANOVA on life satisfaction ---\n\n")

cat("Italy 5D:\n")
aov_it5 <- anova_lifesat(italy_std, italy_clust, as.integer(factor(as.character(italy_clust$profile))))
print(aov_it5)
F_it5 <- if (!is.null(aov_it5)) aov_it5$`F value`[1] else NA_real_

cat("\nItaly 4D:\n")
aov_it4 <- anova_lifesat(italy_std, italy_clust, it4$cluster)
print(aov_it4)
F_it4 <- if (!is.null(aov_it4)) aov_it4$`F value`[1] else NA_real_

cat("\nSweden 5D:\n")
aov_se5 <- anova_lifesat(sweden_std, sweden_clust, as.integer(factor(as.character(sweden_clust$profile))))
print(aov_se5)
F_se5 <- if (!is.null(aov_se5)) aov_se5$`F value`[1] else NA_real_

cat("\nSweden 4D:\n")
aov_se4 <- anova_lifesat(sweden_std, sweden_clust, se4$cluster)
print(aov_se4)
F_se4 <- if (!is.null(aov_se4)) aov_se4$`F value`[1] else NA_real_


# ----- Fragile-split check --------------------------------------------------
# The key qualitative claim: the 4D solution collapses the Fragile Resigned /
# Fragile Depressed distinction that the 5D solution separates.
# Tabulate the cross-classification for Italy.
cat("\n--- Italy: cross-tab of 5D profile vs 4D cluster (k=5) ---\n")
cross_tab <- table(profile_5d = italy_clust$profile, cluster_4d = it4$cluster)
print(cross_tab)
cat("\n(If 4D collapses Fragile Resigned and Fragile Depressed into the same cluster,\n")
cat(" that cluster will have high counts from both 5D profiles.)\n")


# ----- Append results to thesis_numbers.md ---------------------------------
rnd <- function(x, d = 2) formatC(round(x, d), format = "f", digits = d)
wl  <- function(...) cat(..., "\n", file = out_md, sep = "", append = TRUE)

wl("")
wl("## Chapter 6 -- Sensitivity analysis: 4D vs 5D")
wl("")
wl("**4D specification:** drops loneliness, CASP, hope, interest, expect_alive; clustering")
wl("on ", length(italy_active_4d), " active vars (Italy) and ", length(sweden_active_4d),
   " active vars (Sweden).")
wl("")
wl("### Table 6.4 -- 4D vs 5D sensitivity")
wl("")
wl("| Country | Specification | k | Silhouette | Within R\u00b2 | ANOVA F on lifesat | ARI (vs 5D) |")
wl("|---|---|---|---|---|---|---|")
wl("| Italy  | 5D (reference) | 5 | ", rnd(it5$mean_sil, 3), " | ", rnd(it5$r2, 3),
   " | ", rnd(F_it5, 1), " | --- |")
wl("| Italy  | 4D             | 5 | ", rnd(it4$mean_sil, 3), " | ", rnd(it4$r2, 3),
   " | ", rnd(F_it4, 1), " | ", rnd(ari_italy, 3), " |")
wl("| Sweden | 5D (reference) | 6 | ", rnd(se5$mean_sil, 3), " | ", rnd(se5$r2, 3),
   " | ", rnd(F_se5, 1), " | --- |")
wl("| Sweden | 4D             | 6 | ", rnd(se4$mean_sil, 3), " | ", rnd(se4$r2, 3),
   " | ", rnd(F_se4, 1), " | ", rnd(ari_sweden, 3), " |")
wl("")
wl("### Italy: 5D profile x 4D cluster cross-tab")
wl("")
wl("```")
capture.output(print(cross_tab), file = out_md, append = TRUE)
wl("")
wl("```")

cat("\n============================================================\n")
cat("STEP 21 COMPLETE -- sensitivity results appended to thesis_numbers.md\n")
cat("============================================================\n")
