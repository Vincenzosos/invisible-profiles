# 28_imputation_export.R
# -----------------------------------------------------------------------------
# Export the empirical correlation matrix of the 10 profiler variables
# (z-standardised) for Italy and Sweden in the JSON format consumed by
# webapp/src/data/imputation.json.
#
# Webapp consumer:
#   webapp/src/lib/imputation.ts (matchProfileWithImputation) ships with a
#   placeholder identity correlation matrix. Running this script overwrites
#   imputation.json with the empirical Σ from SHARE Wave 9.
#
# Input: the standardised dataframes produced by step 2 (Italy) and step 4
#   (Sweden), which are the same z-standardised tables used downstream by
#   07_cluster_italy.R / 08_cluster_sweden.R and 22_export_centroids.R.
#
# Output: webapp/src/data/imputation.json
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(jsonlite)
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
out_dir   <- file.path(data_path, "v9", "outputs")
json_out  <- file.path(data_path, "webapp", "src", "data", "imputation.json")

# These two .rds files contain the standardised numeric subset used by
# the K-means engine; same inputs as in 22_export_centroids.R.
italy_std  <- readRDS(file.path(out_dir, "step2_italy_std.rds"))
sweden_std <- readRDS(file.path(out_dir, "step4_sweden_std.rds"))

profiler_vars <- c(
  "sphus", "eurod", "iadl", "fdistress", "internet",
  "sn_size_w9", "fluency", "casp", "loneliness", "hope_future"
)

stopifnot(all(profiler_vars %in% colnames(italy_std)))
stopifnot(all(profiler_vars %in% colnames(sweden_std)))

italy_subset  <- italy_std[,  profiler_vars]
sweden_subset <- sweden_std[, profiler_vars]

cor_italy  <- cor(italy_subset,  use = "complete.obs")
cor_sweden <- cor(sweden_subset, use = "complete.obs")

# Round to 6 decimals so the JSON stays human-diffable.
round_matrix <- function(M) round(M, 6)

payload <- list(
  meta = list(
    generated_on = format(Sys.Date(), "%Y-%m-%d"),
    pipeline     = "v9_empirical",
    method       = "conditional Gaussian over 10 z-standardised profiler variables",
    italy_n      = nrow(italy_subset),
    sweden_n     = nrow(sweden_subset),
    note         = "Empirical correlation matrices from SHARE Wave 9 standardised subset (step2_italy_std.rds / step4_sweden_std.rds)."
  ),
  vars = profiler_vars,
  italy  = list(corr = round_matrix(cor_italy)),
  sweden = list(corr = round_matrix(cor_sweden))
)

write_json(
  payload,
  json_out,
  pretty     = TRUE,
  auto_unbox = TRUE,
  matrix     = "rowmajor"
)

cat("Wrote", json_out, "\n")
cat("Italy  n =", nrow(italy_subset),  "\n")
cat("Sweden n =", nrow(sweden_subset), "\n")
