# ==============================================================================
# FIG_PATHS.R -- Chapter-based routing for thesis figures
# Thesis: "Invisible Profiles" - Bocconi MSc DSBA (course 20570, Prof. Trentini)
#
# Defines which of the six thesis subfolders each figure belongs to, and
# provides a drop-in helper used by save_fig() in Step 12-18 so that every
# PNG / PDF is written directly under the correct chapter folder.
#
# Subfolder layout under v9/figures/:
#   03_data_methods    sample flow, data construction (1 figure)
#   04_italy           main-body Italy figures (12)
#   05_sweden          main-body Sweden figures (11)
#   06_comparison      cross-country and pooled analyses (10)
#   07_robustness      LCA, method / algorithm comparisons, silhouette (12)
#   08_appendix        detailed diagnostics not used in the main body (23)
#
# Single source of truth: changing this file re-routes every figure on the
# next source() of the pipeline; no other file needs editing.
# ==============================================================================

fig_chapter_map <- list(
  "03_data_methods" = c(1),
  "04_italy"        = c(4, 6, 8, 10, 12, 36, 37, 41, 47, 50, 63, 68, 70),
  "05_sweden"       = c(5, 7, 9, 11, 13, 38, 39, 42, 48, 51, 69, 71),
  "06_comparison"   = c(14, 15, 19, 20, 21, 34, 35, 40, 56, 62),
  "07_robustness"   = c(16, 17, 18, 22, 23, 26, 27, 49, 64, 65, 66, 67),
  "08_appendix"     = c(2, 3, 24, 25, 28, 29, 30, 31, 32, 33,
                        43, 44, 45, 46, 52, 53, 54, 55,
                        57, 58, 59, 60, 61, 72, 73)
)

# -----------------------------------------------------------------------------
# fig_subfolder(name) -- returns the chapter subfolder for a figure.
# `name` is either a figure filename stem ("fig_04_fa_loadings_italy") or an
# integer-coerceable value. Falls back to "99_unknown" so a missing mapping
# never silently writes into the flat figures/ root.
# -----------------------------------------------------------------------------
fig_subfolder <- function(name) {
  n <- suppressWarnings(as.integer(sub("^fig_?(\\d+).*", "\\1", as.character(name))))
  if (is.na(n)) return("99_unknown")
  for (sf in names(fig_chapter_map)) {
    if (n %in% fig_chapter_map[[sf]]) return(sf)
  }
  "99_unknown"
}

# -----------------------------------------------------------------------------
# ensure_fig_dir(fig_dir, name) -- returns the full path of the chapter
# subfolder for `name`, creating it on disk if it does not exist yet.
# -----------------------------------------------------------------------------
ensure_fig_dir <- function(fig_dir, name) {
  sf <- fig_subfolder(name)
  out_dir <- file.path(fig_dir, sf)
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  }
  out_dir
}

# Sanity check on source: 73 figures must be assigned.
if (sys.nframe() == 0L) {
  assigned <- unlist(fig_chapter_map)
  stopifnot(length(assigned) == 73L,
            length(unique(assigned)) == 73L,
            all(assigned %in% 1:73))
  cat("fig_paths.R loaded: 73 figures routed across",
      length(fig_chapter_map), "chapter subfolders.\n")
}
