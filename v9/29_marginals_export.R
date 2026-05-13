# 29_marginals_export.R
# -----------------------------------------------------------------------------
# Export 500 equally-spaced empirical quantiles of the 10 profiler
# variables for Italy and Sweden, in the JSON format consumed by
# webapp/src/lib/marginals.ts for the KS pre-flight diagnostic.
#
# Inputs:
#   outputs/step2_italy_clean.rds   (raw SHARE-coded scale — what the KS
#   outputs/step4_sweden_clean.rds   pre-flight needs to compare against
#                                   the cohort's coerced values)
#
# Note: 28_imputation_export.R reads the *_std.rds (z-standardised)
# counterparts because the conditional-Gaussian kernel needs unit
# variance. Here we use the *_clean.rds files instead — same pipeline
# stage, pre-standardisation.
#
# Output:
#   ../webapp/src/data/share_marginals.json  (overwrites placeholder)
#
# Run as:
#   cd <repo>/v9 && Rscript 29_marginals_export.R
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(jsonlite)
})

# Paths are resolved relative to this script's directory (v9/).
out_dir  <- "outputs"
json_out <- file.path("..", "webapp", "src", "data", "share_marginals.json")

italy_raw  <- readRDS(file.path(out_dir, "step2_italy_clean.rds"))
sweden_raw <- readRDS(file.path(out_dir, "step4_sweden_clean.rds"))

profiler_vars <- c(
  "sphus", "eurod", "iadl", "fdistress", "internet",
  "sn_size_w9", "fluency", "casp", "loneliness", "hope_future"
)

stopifnot(all(profiler_vars %in% colnames(italy_raw)))
stopifnot(all(profiler_vars %in% colnames(sweden_raw)))

# Sanity guard: the data feeding the K-means engine is z-standardised
# upstream — but the marginals consumed by the KS pre-flight need to be
# on the SHARE-coded raw scale (because the cohort-side values that get
# tested are coerced/rescaled to SHARE codes, never z-scores). If we
# detect values that look standardised (centred near 0 with sd ≈ 1),
# stop loudly instead of silently writing the wrong reference.
check_scale <- function(df, name) {
  ranges <- vapply(profiler_vars, function(v) {
    col <- df[[v]]
    col <- col[!is.na(col)]
    diff(range(col))
  }, numeric(1))
  if (all(ranges < 6)) {
    stop(sprintf(
      "29_marginals_export.R: %s columns appear to be on a z-standardised scale (max range = %.2f). The KS pre-flight needs SHARE-coded raw values. Re-run after producing a raw-scale subset, or update this script to invert the standardisation using mean/sd from centroids.json.",
      name, max(ranges)
    ))
  }
  invisible(NULL)
}
check_scale(italy_raw,  "italy_raw")
check_scale(sweden_raw, "sweden_raw")

# 500 equally-spaced quantile positions, midpoint convention (matches
# the empirical-CDF sampling used downstream by ksTwoSample on the JS
# side, where the array acts as a discretised sample of size 500).
n_q   <- 500
probs <- seq(0.5 / n_q, 1 - 0.5 / n_q, length.out = n_q)

extract_quantiles <- function(df, vars) {
  out <- list()
  for (v in vars) {
    col <- df[[v]]
    col <- col[!is.na(col)]
    if (length(col) == 0) {
      out[[v]] <- list(quantiles = rep(0, n_q))
      next
    }
    q <- as.numeric(quantile(col, probs = probs, type = 7, names = FALSE))
    out[[v]] <- list(quantiles = round(q, 4))
  }
  out
}

italy_marginals  <- extract_quantiles(italy_raw,  profiler_vars)
sweden_marginals <- extract_quantiles(sweden_raw, profiler_vars)

payload <- list(
  meta = list(
    generated_on = format(Sys.Date(), "%Y-%m-%d"),
    pipeline     = "v9_empirical",
    method       = "500 equally-spaced empirical quantiles per variable per country",
    n_quantiles  = n_q,
    placeholder  = FALSE,
    italy_n      = nrow(italy_raw),
    sweden_n     = nrow(sweden_raw),
    note         = "Empirical marginals from SHARE Wave 9 cleaned subset (step2_italy_clean.rds / step4_sweden_clean.rds), on the SHARE-coded raw scale."
  ),
  vars   = profiler_vars,
  italy  = italy_marginals,
  sweden = sweden_marginals
)

write_json(
  payload,
  json_out,
  pretty     = TRUE,
  auto_unbox = TRUE,
  matrix     = "rowmajor"
)

cat("Wrote", json_out, "\n")
cat("Italy  n =", nrow(italy_raw),  "\n")
cat("Sweden n =", nrow(sweden_raw), "\n")
