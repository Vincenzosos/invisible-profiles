# ==============================================================================
# STEP 22: EXPORT K-MEANS CENTROIDS FOR THE WEBAPP PROFILER
# Thesis: "Invisible Profiles" - Bocconi MSc EMIT (course 20570, Prof. Trentini)
#
# Reads the trained K-means objects from Step 7 (Italy, k=5) and Step 8
# (Sweden, k=6) and exports their cluster centres as a JSON file the webapp
# can consume client-side. The output contains:
#
#   - the full centroids on all 29 / 31 standardised variables
#   - a curated 10-variable subset for the user-facing 10-question profiler,
#     covering all five dimensions (Health, Economic, Digital/Social,
#     Cognitive, Subjective).
#
# The standardisation parameters (mean and sd of the underlying ranked or
# raw values) are also exported so that the webapp can map the user's raw
# answers to the same z-scale on which the centroids live.
#
# OUTPUT: v9/outputs/centroids.json   (used by webapp/src/data/centroids.json)
# ==============================================================================

suppressMessages({
  library(jsonlite)
  library(haven)
  library(dplyr)
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
out_dir   <- file.path(data_path, "v9", "outputs")

cat("============================================================\n")
cat("STEP 22: EXPORT K-MEANS CENTROIDS FOR WEBAPP\n")
cat("============================================================\n\n")

# ---- Load trained K-means objects -----------------------------------------
km_italy  <- readRDS(file.path(out_dir, "step7_italy_kmeans_k5.rds"))
km_sweden <- readRDS(file.path(out_dir, "step8_sweden_kmeans_k6.rds"))

italy_std  <- readRDS(file.path(out_dir, "step2_italy_std.rds"))
sweden_std <- readRDS(file.path(out_dir, "step4_sweden_std.rds"))
italy_clean  <- readRDS(file.path(out_dir, "step2_italy_clean.rds"))
sweden_clean <- readRDS(file.path(out_dir, "step4_sweden_clean.rds"))

# ---- Profile labels (canonical, do not rename) -----------------------------
profile_order_italy  <- c("Fragile Resigned", "Fragile Depressed",
                          "Moderate Isolated", "Traditional Social",
                          "Connected Active")
profile_order_sweden <- c("Fragile", "Social Decline", "Moderate",
                          "Asset Rich", "Wealthy Digital", "Connected Wealthy")

# ---- Variable curation: 10-question subset ---------------------------------
# Five dimensions × representative variables. These are answerable by an
# elderly respondent (or a caregiver) in plain Italian without specialist
# vocabulary. Each scale is documented in the JSON for the webapp form.
key_vars <- list(
  # Health
  list(var = "sphus",        dim = "Health",     scale = "1-5",   label = "Self-rated health (1=excellent, 5=poor)"),
  list(var = "eurod",        dim = "Health",     scale = "0-12",  label = "EURO-D depression score"),
  list(var = "iadl",         dim = "Health",     scale = "0-7",   label = "Instrumental ADL limitations"),
  # Economic
  list(var = "fdistress",    dim = "Economic",   scale = "1-4",   label = "Difficulty making ends meet (1=great difficulty, 4=easily)"),
  # Digital/Social
  list(var = "internet",     dim = "Digital",    scale = "0/1",   label = "Used internet in past 7 days"),
  list(var = "sn_size_w9",   dim = "Social",     scale = "1-7",   label = "Size of social network (number of confidants)"),
  # Cognitive
  list(var = "fluency",      dim = "Cognitive",  scale = "count", label = "Number of animals named in 60s"),
  # Subjective
  list(var = "casp",         dim = "Subjective", scale = "12-48", label = "Quality of life (CASP-12)"),
  list(var = "loneliness",   dim = "Subjective", scale = "3-9",   label = "UCLA loneliness scale"),
  list(var = "hope_future",  dim = "Subjective", scale = "0/1",   label = "Reports hopes for the future")
)
key_var_names <- vapply(key_vars, `[[`, character(1), "var")

# ---- Helpers ---------------------------------------------------------------
num <- function(x) as.numeric(haven::zap_labels(x))

centroid_block <- function(km, profile_levels, std_df, clean_df) {
  centers <- km$centers
  rownames(centers) <- profile_levels[seq_len(nrow(centers))]

  # Standardisation parameters: mean and sd on the *clean* data (pre-z-score)
  # so the webapp can convert a raw user answer into the same z-scale.
  raw_means <- vapply(colnames(centers),
                      function(v) mean(num(clean_df[[v]]), na.rm = TRUE),
                      numeric(1))
  raw_sds   <- vapply(colnames(centers),
                      function(v) stats::sd(num(clean_df[[v]]), na.rm = TRUE),
                      numeric(1))

  list(
    profiles  = lapply(seq_len(nrow(centers)), function(i) {
      list(
        name   = rownames(centers)[i],
        center = unname(centers[i, ])
      )
    }),
    variables = lapply(seq_len(ncol(centers)), function(j) {
      v <- colnames(centers)[j]
      list(
        name      = v,
        raw_mean  = unname(raw_means[v]),
        raw_sd    = unname(raw_sds[v])
      )
    })
  )
}

# ---- Build the export object ----------------------------------------------
out <- list(
  meta = list(
    generated_on   = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    pipeline       = "v9",
    italy_n        = nrow(italy_std),
    sweden_n       = nrow(sweden_std),
    italy_k        = nrow(km_italy$centers),
    sweden_k       = nrow(km_sweden$centers),
    notes          = "Centers in z-score space. Use raw_mean and raw_sd to convert user input."
  ),
  italy_full   = centroid_block(km_italy,  profile_order_italy,  italy_std,  italy_clean),
  sweden_full  = centroid_block(km_sweden, profile_order_sweden, sweden_std, sweden_clean),
  key_variables = key_vars,
  italy_subset = list(
    profiles  = lapply(seq_len(nrow(km_italy$centers)), function(i) {
      vec <- km_italy$centers[i, intersect(key_var_names, colnames(km_italy$centers))]
      list(
        name   = profile_order_italy[i],
        center = unname(vec),
        vars   = names(vec)
      )
    })
  ),
  sweden_subset = list(
    profiles  = lapply(seq_len(nrow(km_sweden$centers)), function(i) {
      vec <- km_sweden$centers[i, intersect(key_var_names, colnames(km_sweden$centers))]
      list(
        name   = profile_order_sweden[i],
        center = unname(vec),
        vars   = names(vec)
      )
    })
  )
)

# ---- Write JSON -----------------------------------------------------------
out_file <- file.path(out_dir, "centroids.json")
write_json(out, out_file, pretty = TRUE, auto_unbox = TRUE, digits = 6)

cat("Exported:", out_file, "\n")
cat("  Italy : k = ", nrow(km_italy$centers),
    " on ", ncol(km_italy$centers), " full vars / ",
    length(intersect(key_var_names, colnames(km_italy$centers))), " key vars\n", sep = "")
cat("  Sweden: k = ", nrow(km_sweden$centers),
    " on ", ncol(km_sweden$centers), " full vars / ",
    length(intersect(key_var_names, colnames(km_sweden$centers))), " key vars\n", sep = "")
cat("\n")
cat("STEP 22 COMPLETE -- ready for the webapp.\n")
