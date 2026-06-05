# ==============================================================================
# STEP 40: IMPUTATION-REPLICATE SENSITIVITY  (Appendix A.5)
# Thesis: "Invisible Profiles"
#
# Question (anticipates supervisor objection on §7.2): the deployed partition
# uses SHARE multiple-imputation draw implicat == 1 for the imputed
# health/economic/cognitive variables. How much does the K-means partition
# change if we redraw the imputation (implicat == 2 and == 3)?
#
# Procedure (IDENTICAL across implicat, only the imputation draw differs):
#   1. Re-assemble Italy (country 16) and Sweden (country 13) from the raw
#      SHARE W9 modules for implicat = 1, 2, 3. Only gv_imputations-sourced
#      variables depend on implicat; the non-imputed modules (networks, ac,
#      sp, mh, ex) are held fixed.
#   2. Re-run preprocessing: listwise deletion on the 31 analytical variables,
#      rank-transform the 20 non-binary variables, z-score all 31, Mahalanobis
#      outlier removal (chi-squared, df = #non-degenerate vars, p < 0.001).
#   3. Re-run K-means at the DEPLOYED k (5 Italy, 6 Sweden), seed 42.
#   4. Compute the Adjusted Rand Index (ARI) between the implicat = 2 / 3
#      partition and the implicat = 1 partition on the common respondents
#      (matched by mergeid). ARI is invariant to cluster-label permutation.
#      Also report concordance with the deployed partition as a sanity anchor.
#
# OUTPUT: v9/outputs/imputation_sensitivity.json
# ==============================================================================

suppressMessages({
  library(haven)
  library(dplyr)
})

data_path <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"

# --- variable blocks (identical to steps 1-4) -------------------------------
health_vars  <- c("sphus","chronic","adl","iadl","mobility","eurod","bmi","phinact")
econ_vars    <- c("log_thinc","log_hnetw","ypen1","home_own","fdistress")
digital_vars <- c("internet","ac035d1","ac035d5","ac035d8",
                  "sp002_","sp008_","sn_size_w9","social_integration",
                  "ac035d4","ac035d7")
cog_vars     <- c("fluency","memory","orienti")
subj_vars    <- c("loneliness","casp","hope_future","interest","expect_alive")
all_31       <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)
binary_vars  <- c("phinact","home_own","internet","ac035d1","ac035d5",
                  "ac035d8","sp002_","sp008_","ac035d4","ac035d7","hope_future")
nonbinary_vars <- setdiff(all_31, binary_vars)

# --- load raw modules ONCE --------------------------------------------------
load_module <- function(m) {
  fp <- file.path(data_path, "_share_data", paste0("sharew9_rel9-0-0_", m, ".dta"))
  read_dta(fp)
}
cat("Loading raw SHARE W9 modules ...\n")
gv_imp <- load_module("gv_imputations")
gv_net <- load_module("gv_networks")
ac     <- load_module("ac")
sp     <- load_module("sp")
mh     <- load_module("mh")
ex     <- load_module("ex")
cat("  done.\n\n")

# --- assemble one country x one implicat (replicates step 1 / step 3) -------
assemble <- function(cc, imp) {
  core <- gv_imp %>%
    filter(country == cc, implicat == imp, age >= 65) %>%
    select(mergeid, gender, age, sphus, chronic, adl, iadl, mobility, eurod,
           bmi, phinact, thinc, hnetw, ypen1, home, fdistress, internet,
           fluency, memory, orienti) %>%
    mutate(home_own = ifelse(home > 0, 1, 0),
           fdistress = ifelse(fdistress < 0, NA_real_, fdistress)) %>%
    select(-home)

  networks <- gv_net %>% filter(country == cc) %>%
    select(mergeid, sn_size_w9, social_integration) %>%
    mutate(sn_size_w9 = ifelse(sn_size_w9 < 0, NA_real_, sn_size_w9),
           social_integration = ifelse(social_integration < 0, NA_real_, social_integration))

  activities <- ac %>% filter(country == cc) %>%
    select(mergeid, ac035d1, ac035d4, ac035d5, ac035d7, ac035d8,
           ac014_, ac015_, ac016_, ac017_, ac018_, ac019_,
           ac020_, ac021_, ac022_, ac023_, ac024_, ac025_) %>%
    mutate(across(-mergeid, ~ ifelse(. < 0, NA_real_, .))) %>%
    mutate(casp = ac014_ + ac015_ + ac016_ + (5 - ac017_) + ac018_ + ac019_ +
                  (5 - ac020_) + (5 - ac021_) + (5 - ac022_) +
                  (5 - ac023_) + (5 - ac024_) + (5 - ac025_)) %>%
    select(mergeid, ac035d1, ac035d4, ac035d5, ac035d7, ac035d8, casp)

  social_part <- sp %>% filter(country == cc) %>%
    select(mergeid, sp002_, sp008_) %>%
    mutate(sp002_ = case_when(sp002_ == 1 ~ 1, sp002_ == 5 ~ 0, TRUE ~ NA_real_),
           sp008_ = case_when(sp008_ == 1 ~ 1, sp008_ == 5 ~ 0, TRUE ~ NA_real_))

  mental <- mh %>% filter(country == cc) %>%
    select(mergeid, mh003_, mh008_, mh035_, mh036_, mh037_) %>%
    mutate(across(-mergeid, ~ ifelse(. < 0, NA_real_, .))) %>%
    mutate(loneliness = (4 - mh035_) + (4 - mh036_) + (4 - mh037_),
           hope_future = case_when(mh003_ == 1 ~ 1, mh003_ == 2 ~ 0, TRUE ~ NA_real_),
           interest = ifelse(mh008_ %in% c(1, 2, 3), mh008_, NA_real_)) %>%
    select(mergeid, loneliness, hope_future, interest)

  expectations <- ex %>% filter(country == cc) %>%
    select(mergeid, ex009_) %>%
    mutate(expect_alive = ifelse(ex009_ < 0, NA_real_, ex009_)) %>%
    select(mergeid, expect_alive)

  df <- core %>%
    left_join(networks, by = "mergeid") %>%
    left_join(activities, by = "mergeid") %>%
    left_join(social_part, by = "mergeid") %>%
    left_join(mental, by = "mergeid") %>%
    left_join(expectations, by = "mergeid") %>%
    mutate(log_thinc = log(pmax(thinc, 0) + 1),
           log_hnetw = log(pmax(hnetw, 0) + 1))
  df
}

# --- preprocess: listwise + rank + z-score + Mahalanobis (steps 2 / 4) ------
preprocess <- function(df) {
  d <- df %>% filter(complete.cases(across(all_of(all_31))))
  for (v in nonbinary_vars) d[[v]] <- rank(d[[v]], ties.method = "average")
  for (v in all_31)        d[[v]] <- as.numeric(scale(d[[v]]))
  # Mahalanobis on non-degenerate columns only (avoids singular covariance)
  sds <- sapply(d[, all_31], sd)
  mvars <- all_31[is.finite(sds) & sds > 0]
  X <- as.matrix(d[, mvars])
  md <- mahalanobis(X, colMeans(X), cov(X))
  cutoff <- qchisq(0.999, df = length(mvars))
  d[md <= cutoff, , drop = FALSE]
}

# --- cluster: exclude zero-var, K-means seed 42 (steps 7 / 8) ---------------
cluster_km <- function(d_std, k, nstart) {
  sds <- sapply(d_std[, all_31], sd)
  active <- all_31[is.finite(sds) & sds > 0]
  X <- as.matrix(d_std[, active])
  set.seed(42)
  km <- kmeans(X, centers = k, nstart = nstart, iter.max = 500)
  data.frame(mergeid = d_std$mergeid, cl = km$cluster, stringsAsFactors = FALSE)
}

# --- Adjusted Rand Index (permutation-invariant) ----------------------------
ari <- function(a, b) {
  tab <- table(a, b)
  cc2 <- function(x) sum(choose(x, 2))
  idx <- cc2(as.vector(tab))
  sa  <- cc2(rowSums(tab)); sb <- cc2(colSums(tab))
  n   <- sum(tab); tot <- choose(n, 2)
  expected <- sa * sb / tot
  maxi <- 0.5 * (sa + sb)
  (idx - expected) / (maxi - expected)
}

# --- Cluster-level purity: map each cluster of `a` to dominant cluster of `b`
purity <- function(a, b) {
  tab <- table(a, b)
  sum(apply(tab, 1, max)) / sum(tab)
}

# --- run for both countries -------------------------------------------------
run_country <- function(cc, k, nstart, label) {
  cat(sprintf("=== %s (country %d, k=%d) ===\n", label, cc, k))
  parts <- list()
  for (imp in 1:3) {
    d <- preprocess(assemble(cc, imp))
    parts[[as.character(imp)]] <- cluster_km(d, k, nstart)
    cat(sprintf("  implicat %d: n=%d after cleaning\n", imp, nrow(parts[[as.character(imp)]])))
  }
  common <- function(pa, pb) {
    m <- inner_join(pa, pb, by = "mergeid", suffix = c("_a", "_b"))
    list(ari = ari(m$cl_a, m$cl_b), pur = purity(m$cl_a, m$cl_b), n = nrow(m))
  }
  r21 <- common(parts[["2"]], parts[["1"]])
  r31 <- common(parts[["3"]], parts[["1"]])
  r32 <- common(parts[["3"]], parts[["2"]])
  cat(sprintf("  ARI(imp2 vs imp1) = %.3f  purity = %.3f  (n=%d common)\n", r21$ari, r21$pur, r21$n))
  cat(sprintf("  ARI(imp3 vs imp1) = %.3f  purity = %.3f  (n=%d common)\n", r31$ari, r31$pur, r31$n))
  cat(sprintf("  ARI(imp3 vs imp2) = %.3f  purity = %.3f  (n=%d common)\n", r32$ari, r32$pur, r32$n))
  saveRDS(parts, file.path(data_path, "v9", "outputs",
          sprintf("imputation_parts_%s.rds", tolower(label))))
  list(parts = parts, ari21 = r21$ari, pur21 = r21$pur, n21 = r21$n,
       ari31 = r31$ari, pur31 = r31$pur, n31 = r31$n,
       ari32 = r32$ari, pur32 = r32$pur, n32 = r32$n)
}

# nstart raised to 100 for both countries to suppress K-means initialisation
# noise, so the ARI reflects the imputation draw rather than the random restart.
it <- run_country(16, 5, 100, "ITALY")
cat("\n")
se <- run_country(13, 6, 100, "SWEDEN")

# --- sanity anchor: reproduced implicat==1 vs DEPLOYED partition -------------
cat("\n=== Sanity anchor: reproduced imp1 vs deployed (step7/step8) ===\n")
dep_it <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
dep_se <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_with_clusters.rds"))
anchor <- function(parts1, dep, lab) {
  d <- data.frame(mergeid = dep$mergeid, cl = as.integer(dep$cluster_num))
  m <- inner_join(parts1, d, by = "mergeid", suffix = c("_r", "_d"))
  a <- ari(m$cl_r, m$cl_d)
  cat(sprintf("  %s: ARI(reproduced imp1 vs deployed) = %.3f (n=%d common)\n", lab, a, nrow(m)))
  a
}
anc_it <- anchor(it$parts[["1"]], dep_it, "ITALY")
anc_se <- anchor(se$parts[["1"]], dep_se, "SWEDEN")

# --- write JSON -------------------------------------------------------------
out <- sprintf(paste0(
  '{\n  "description": "Imputation-replicate sensitivity (App A.5). ARI and cluster purity between K-means partitions under SHARE imputation draws implicat 2/3 vs implicat 1, identical pipeline (nstart=100).",\n',
  '  "italy":  {"k": 5, "ari_imp2_vs_imp1": %.3f, "purity_imp2_vs_imp1": %.3f, "ari_imp3_vs_imp1": %.3f, "purity_imp3_vs_imp1": %.3f, "ari_imp3_vs_imp2": %.3f, "n_common": %d, "anchor_repro_vs_deployed": %.3f},\n',
  '  "sweden": {"k": 6, "ari_imp2_vs_imp1": %.3f, "purity_imp2_vs_imp1": %.3f, "ari_imp3_vs_imp1": %.3f, "purity_imp3_vs_imp1": %.3f, "ari_imp3_vs_imp2": %.3f, "n_common": %d, "anchor_repro_vs_deployed": %.3f}\n}\n'),
  it$ari21, it$pur21, it$ari31, it$pur31, it$ari32, it$n21, anc_it,
  se$ari21, se$pur21, se$ari31, se$pur31, se$ari32, se$n21, anc_se)
writeLines(out, file.path(data_path, "v9", "outputs", "imputation_sensitivity.json"))
cat("\nSaved: v9/outputs/imputation_sensitivity.json\n")
cat(out)
