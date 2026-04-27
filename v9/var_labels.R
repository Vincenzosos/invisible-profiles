# ==============================================================================
# VAR_LABELS.R -- Central human-readable labels for active SHARE Wave 9 vars
# Thesis: "Invisible Profiles" - Bocconi MSc DSBA (course 20570, Prof. Trentini)
#
# Provides, for every analytical variable used in clustering and factor analysis:
#   - var_labels       short concise label (fits axis tick / facet strip)
#   - var_labels_scale concise label + measurement scale in parentheses
#                      (used where there is room: heatmap rows, captions)
#   - var_block        mapping to the five dimensional blocks used in the
#                      profile plots (Health / Economy / Digital / Social /
#                      Cognitive / Subjective)
#   - var_block_colours palette used to colour labels by block
#   - relabel()        helper that accepts technical names and returns the
#                      chosen label vector (short by default)
#
# Source this file at the top of any figure script that exposes variable
# names in axes, facet strips, legends or heatmap rows:
#
#     source(file.path(data_path, "v9", "var_labels.R"))
#
# DO NOT rename variables or modify block assignments here without updating
# the COWORK_PROJECT_BRIEF.md -- these names are canonical for the thesis.
# ==============================================================================

# -----------------------------------------------------------------------------
# SHORT LABELS (canonical; match those already used in 15_profile_plots.R)
# -----------------------------------------------------------------------------
var_labels <- c(
  # Health (8)
  "sphus"              = "Self-rated health",
  "chronic"            = "Chronic diseases",
  "adl"                = "ADL limitations",
  "iadl"               = "IADL limitations",
  "mobility"           = "Mobility limit.",
  "eurod"              = "Depression (EURO-D)",
  "bmi"                = "BMI",
  "phinact"            = "Phys. inactive",
  # Economic (5)
  "log_thinc"          = "Income (log)",
  "log_hnetw"          = "Net wealth (log)",
  "ypen1"              = "Pension income",
  "home_own"           = "Home owner",
  "fdistress"          = "Financial distress",
  # Digital / Social (10)
  "internet"           = "Internet use",
  "ac035d1"            = "Sport/club",
  "ac035d4"            = "Training course",
  "ac035d5"            = "Volunteering",
  "ac035d7"            = "Political org.",
  "ac035d8"            = "Educational course",
  "sp002_"             = "Received help",
  "sp008_"             = "Gave help",
  "sn_size_w9"         = "Network size",
  "social_integration" = "Social integration",
  # Cognitive (3)
  "fluency"            = "Verbal fluency",
  "memory"             = "Memory recall",
  "orienti"            = "Orientation",
  # Subjective (5)
  "loneliness"         = "Loneliness",
  "casp"               = "Quality of life (CASP)",
  "hope_future"        = "Hopeful future",
  "interest"           = "Interest in things",
  "expect_alive"       = "Life expectancy"
)

# -----------------------------------------------------------------------------
# EXTENDED LABELS with measurement scale (used where vertical/row space allows)
# Scales reconstructed from SHARE Wave 9 documentation and the derivations in
# 01_data_assembly.R (sphus 1-5 reversed so higher = worse; eurod 0-12; casp
# 12-36; adl 0-6; iadl 0-7; loneliness 3-9; orienti 0-4; memory 0-20;
# social_integration 1-4; sn_size_w9 1-7; interest 1-3; fdistress 1-4).
# Binary indicators are flagged "(0/1)" so readers do not miss it.
# -----------------------------------------------------------------------------
var_labels_scale <- c(
  "sphus"              = "Self-rated health (1-5)",
  "chronic"            = "Chronic diseases (count)",
  "adl"                = "ADL limitations (0-6)",
  "iadl"               = "IADL limitations (0-7)",
  "mobility"           = "Mobility limitations (count)",
  "eurod"              = "Depression EURO-D (0-12)",
  "bmi"                = "Body mass index",
  "phinact"            = "Physical inactivity (0/1)",
  "log_thinc"          = "Household income (log EUR)",
  "log_hnetw"          = "Household net wealth (log EUR)",
  "ypen1"              = "Public pension income (EUR)",
  "home_own"           = "Home ownership (0/1)",
  "fdistress"          = "Financial distress (1-4)",
  "internet"           = "Internet use (0/1)",
  "ac035d1"            = "Sport / social club (0/1)",
  "ac035d4"            = "Training course (0/1)",
  "ac035d5"            = "Voluntary work (0/1)",
  "ac035d7"            = "Political / community org. (0/1)",
  "ac035d8"            = "Educational course (0/1)",
  "sp002_"             = "Received help (0/1)",
  "sp008_"             = "Gave help (0/1)",
  "sn_size_w9"         = "Social network size (1-7)",
  "social_integration" = "Social integration index (1-4)",
  "fluency"            = "Verbal fluency (animals/min)",
  "memory"             = "Memory recall (0-20)",
  "orienti"            = "Orientation (0-4)",
  "loneliness"         = "Loneliness R-UCLA (3-9)",
  "casp"               = "Quality of life CASP-12 (12-36)",
  "hope_future"        = "Hopeful about future (0/1)",
  "interest"           = "Interest in things (1-3)",
  "expect_alive"       = "Life expectancy self-rated (0-100)"
)

# -----------------------------------------------------------------------------
# DIMENSIONAL BLOCK ASSIGNMENT
# Single source of truth used by every figure that colours labels by block
# (fig_50/51 profile plots, fig_66/67 heatmaps, fig_68/69 boxplots).
# -----------------------------------------------------------------------------
var_block <- c(
  # Health
  "sphus"              = "Health",
  "chronic"            = "Health",
  "adl"                = "Health",
  "iadl"               = "Health",
  "mobility"           = "Health",
  "eurod"              = "Health",
  "bmi"                = "Health",
  "phinact"            = "Health",
  # Economic
  "log_thinc"          = "Economic",
  "log_hnetw"          = "Economic",
  "ypen1"              = "Economic",
  "home_own"           = "Economic",
  "fdistress"          = "Economic",
  # Digital / Social
  "internet"           = "Digital/Social",
  "ac035d1"            = "Digital/Social",
  "ac035d4"            = "Digital/Social",
  "ac035d5"            = "Digital/Social",
  "ac035d7"            = "Digital/Social",
  "ac035d8"            = "Digital/Social",
  "sp002_"             = "Digital/Social",
  "sp008_"             = "Digital/Social",
  "sn_size_w9"         = "Digital/Social",
  "social_integration" = "Digital/Social",
  # Cognitive
  "fluency"            = "Cognitive",
  "memory"             = "Cognitive",
  "orienti"            = "Cognitive",
  # Subjective
  "loneliness"         = "Subjective",
  "casp"               = "Subjective",
  "hope_future"        = "Subjective",
  "interest"           = "Subjective",
  "expect_alive"       = "Subjective"
)

# Palette for dimensional blocks (consistent across all figures)
var_block_colours <- c(
  "Health"         = "#C0392B",  # red
  "Economic"       = "#27AE60",  # green
  "Digital/Social" = "#2874A6",  # blue
  "Cognitive"      = "#7D3C98",  # purple
  "Subjective"     = "#D68910"   # orange
)

# Canonical ordering of the five blocks (figures loop over this)
var_block_levels <- c("Health", "Economic", "Digital/Social",
                      "Cognitive", "Subjective")

# -----------------------------------------------------------------------------
# relabel() -- vectorised helper
#
# Arguments:
#   x       character vector of technical names (e.g. c("sphus","casp"))
#   style   "short" (default) or "scale"
#   fallback  logical; if TRUE unknown names are returned unchanged;
#             if FALSE they are returned as NA_character_.
#
# Returns a character vector the same length as x.
# -----------------------------------------------------------------------------
relabel <- function(x, style = c("short", "scale"), fallback = TRUE) {
  style <- match.arg(style)
  dict  <- if (style == "scale") var_labels_scale else var_labels
  out   <- unname(dict[as.character(x)])
  if (fallback) {
    na_mask <- is.na(out)
    out[na_mask] <- as.character(x)[na_mask]
  }
  out
}

# block_of() -- returns the dimensional block for a given technical name
block_of <- function(x) unname(var_block[as.character(x)])

# Quick sanity check when sourced interactively
if (sys.nframe() == 0L) {
  stopifnot(length(var_labels) == 31L,
            length(var_labels_scale) == 31L,
            length(var_block) == 31L,
            setequal(names(var_labels), names(var_labels_scale)),
            setequal(names(var_labels), names(var_block)))
  cat("var_labels.R loaded: 31 variables x 2 label styles x 5 blocks.\n")
}
