# ==============================================================================
# STEP 15: CANONICAL PROFILE PLOTS (Course 20570 Trentini)
# Thesis: "Invisible Profiles" — Bocconi MSc DSBA
#
# Aggiunge i "profile plot" canonici del corso (hands-on Cluster item 34):
# line plot su TUTTE le variabili attive (x-axis), z-score mean per cluster
# (y-axis), lines colorate per profilo, background per dimensione.
#
# Questo è IL grafico che riassume meglio i profili — mostra come ogni cluster
# devia dalla media globale su ciascuna delle 29/31 variabili analitiche.
#
#   Fig 50  Profile plot — Italy (5 profiles × 29 vars)
#   Fig 51  Profile plot — Sweden (6 profiles × 31 vars)
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(viridis)
  if (!requireNamespace("haven", quietly = TRUE)) install.packages("haven", quiet = TRUE)
  library(haven)  # per zap_labels
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
fig_dir   <- file.path(data_path, "v9", "figures")

# Central var_labels / var_labels_scale / var_block dictionary.
# This script used to carry its own copy of var_labels; it now inherits
# from the shared v9/var_labels.R so the wording is identical across all
# figures (fig_04/05, fig_47/48, fig_50/51, fig_66/67, fig_68/69).
source(file.path(data_path, "v9", "var_labels.R"))
# Chapter-subfolder routing for save_fig().
source(file.path(data_path, "v9", "fig_paths.R"))

cat("============================================================\n")
cat("STEP 15: CANONICAL PROFILE PLOTS\n")
cat("============================================================\n\n")

# ---- Theme + helpers (identici a Step 12/13/14) ----
theme_thesis <- function(base_size = 11) {
  theme_classic(base_size = base_size) +
    theme(
      text = element_text(family = "sans"),
      plot.title = element_text(face = "bold", size = base_size + 1, hjust = 0),
      plot.subtitle = element_text(size = base_size - 1, colour = "grey30"),
      axis.title = element_text(size = base_size),
      axis.text = element_text(size = base_size - 1),
      legend.title = element_text(size = base_size - 1, face = "bold"),
      legend.text = element_text(size = base_size - 1),
      strip.text = element_text(face = "bold", size = base_size),
      strip.background = element_rect(fill = "grey92", colour = NA),
      panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3),
      plot.caption = element_text(size = base_size - 2, colour = "grey40", hjust = 0)
    )
}
profile_palette <- function(n) viridis::viridis(n, option = "D", end = 0.85)
save_fig <- function(p, name, w = 7, h = 5, also_pdf = FALSE) {
  out_dir <- ensure_fig_dir(fig_dir, name)
  base    <- file.path(out_dir, name)
  ggsave(paste0(base, ".png"), p, width = w, height = h, dpi = 300, bg = "white")
  if (also_pdf) ggsave(paste0(base, ".pdf"), p, width = w, height = h, bg = "white")
  cat(sprintf("    \u2713 %s  (%.1fx%.1f in)  -> %s/\n",
              name, w, h, basename(out_dir)))
}

# ---- Load data ----
cat("--- Loading ---\n")
italy_std    <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_std.rds"))
sweden_std   <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_std.rds"))
italy_clust  <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
sweden_clust <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_with_clusters.rds"))
cat("  ...loaded\n\n")

# Variables by dimension (preserva ordine per colorazione background)
dim_vars <- list(
  "Health"     = c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact"),
  "Economic"   = c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress"),
  "Digital"    = c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7"),
  "Cognitive"  = c("fluency", "memory", "orienti"),
  "Subjective" = c("loneliness", "casp", "hope_future", "interest", "expect_alive")
)
all_vars_ordered <- unlist(dim_vars, use.names = FALSE)

# Dimension color palette for backgrounds
dim_colors <- c(
  "Health"     = "#FFE5E5",
  "Economic"   = "#FFF2E0",
  "Digital"    = "#E8F0E3",
  "Cognitive"  = "#E0F0F7",
  "Subjective" = "#F5E8F2"
)

# Human-readable variable labels -> now loaded from v9/var_labels.R
# (vectors var_labels, var_labels_scale, var_block are already in scope).

profile_order_italy  <- c("Fragile Resigned", "Fragile Depressed",
                          "Moderate Isolated", "Traditional Social",
                          "Connected Active")
profile_order_sweden <- c("Fragile", "Social Decline", "Moderate",
                          "Asset Rich", "Wealthy Digital", "Connected Wealthy")


# ##############################################################################
# PROFILE PLOT FUNCTION
# ##############################################################################

plot_profile <- function(df_std, df_clust, active_vars, profile_order,
                          country_name, country_n, fig_num) {

  # Extract std vars
  used_vars <- intersect(active_vars, names(df_std))

  # Build explicit numeric matrix cell-by-cell
  n_rows <- nrow(df_std)
  mat <- matrix(NA_real_, nrow = n_rows, ncol = length(used_vars))
  colnames(mat) <- used_vars
  for (j in seq_along(used_vars)) {
    v <- used_vars[j]
    x <- df_std[[v]]
    x <- unclass(x)
    attributes(x) <- NULL
    mat[, j] <- suppressWarnings(as.numeric(x))
  }

  # Build long-form means via base R (avoid pivot_longer type issues)
  prof <- as.character(df_clust$profile)
  rows_list <- list()
  for (p in profile_order) {
    mask <- which(prof == p)
    if (length(mask) == 0) next
    sub <- mat[mask, , drop = FALSE]
    means_p <- colMeans(sub, na.rm = TRUE)
    for (j in seq_along(used_vars)) {
      rows_list[[length(rows_list) + 1]] <- data.frame(
        profile  = p,
        variable = used_vars[j],
        mean_z   = means_p[j],
        stringsAsFactors = FALSE
      )
    }
  }
  means <- do.call(rbind, rows_list)
  # Force clean numeric
  means$mean_z <- as.numeric(means$mean_z)

  # Add dimension labels
  var_dim <- data.frame(
    variable = unlist(dim_vars, use.names = FALSE),
    dimension = rep(names(dim_vars), sapply(dim_vars, length)),
    stringsAsFactors = FALSE
  )
  means <- merge(means, var_dim, by = "variable", all.x = TRUE)

  # Factors (preserve order)
  means$variable  <- factor(means$variable, levels = active_vars)
  means$profile   <- factor(means$profile,  levels = profile_order)
  means$dimension <- factor(means$dimension,
                             levels = c("Health", "Economic", "Digital",
                                        "Cognitive", "Subjective"))

  # Diagnostic print (always, to confirm)
  cat(sprintf("    Means computed: %d rows, %d NA. Range: [%.2f, %.2f]\n",
              nrow(means),
              sum(is.na(means$mean_z) | is.nan(means$mean_z)),
              min(means$mean_z, na.rm = TRUE),
              max(means$mean_z, na.rm = TRUE)))

  # SINGLE-PANEL layout (course 20570 canon): x-axis labels colored per
  # dimension, vertical dividers between dimensions, no facet.
  n_profiles <- length(profile_order)

  # Compute x positions and dimension boundaries
  means <- means[order(means$variable), ]
  var_order <- levels(means$variable)
  # Dimension color key (for x-axis labels)
  dim_color_key <- c(
    "Health"     = "#B22222",
    "Economic"   = "#CC8800",
    "Digital"    = "#2E7D32",
    "Cognitive"  = "#1565C0",
    "Subjective" = "#6A1B9A"
  )
  # Map each variable to its dimension color (for axis label coloring)
  var_dim_lookup <- setNames(var_dim$dimension, var_dim$variable)
  axis_label_colors <- dim_color_key[var_dim_lookup[var_order]]

  # Find boundaries between consecutive dimensions (for vertical dividers)
  dim_seq <- as.character(var_dim_lookup[var_order])
  boundaries <- which(dim_seq[-1] != dim_seq[-length(dim_seq)]) + 0.5

  # Compute dimension label positions for top annotations
  dim_positions <- data.frame(
    dimension = unique(dim_seq),
    stringsAsFactors = FALSE
  )
  dim_positions$x_mid <- sapply(dim_positions$dimension, function(d) {
    idx <- which(dim_seq == d)
    mean(range(idx))
  })

  y_lims <- range(means$mean_z, na.rm = TRUE)
  y_pad  <- 0.15 * diff(y_lims)
  y_top  <- y_lims[2] + y_pad

  # Use human-readable labels
  readable_labels <- var_labels[var_order]
  # Fallback for any variable not in the lookup
  readable_labels[is.na(readable_labels)] <- var_order[is.na(readable_labels)]

  ggplot(means, aes(x = variable, y = mean_z,
                     colour = profile, group = profile)) +
    # Reference line
    geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.4) +
    # Vertical dividers between dimensions
    geom_vline(xintercept = boundaries, linetype = "dotted",
               colour = "grey70", linewidth = 0.4) +
    # Profile lines
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.6) +
    # Dimension labels at top
    annotate("text",
             x = dim_positions$x_mid,
             y = y_top,
             label = dim_positions$dimension,
             fontface = "bold", size = 3.8,
             colour = dim_color_key[dim_positions$dimension]) +
    scale_colour_manual(values = profile_palette(n_profiles), name = "Profile") +
    scale_x_discrete(labels = readable_labels) +
    scale_y_continuous(limits = c(y_lims[1] - 0.05 * diff(y_lims),
                                   y_top + 0.05 * diff(y_lims)),
                       expand = c(0, 0)) +
    labs(title = sprintf("Figure %d. Profile plot, %s", fig_num, country_name),
         subtitle = sprintf("Mean z-score per profile across all %d analytical variables (n=%s)",
                             length(active_vars), format(country_n, big.mark = ",")),
         x = NULL, y = "Standardized mean (z-score)",
         caption = "Dashed line = overall mean (z = 0). Dotted verticals separate conceptual dimensions. X-axis labels colored by dimension. Each line = one profile centroid.") +
    theme_thesis() +
    theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 8.5,
                                      colour = axis_label_colors),
          panel.grid.major.x = element_blank(),
          legend.position = "top")
}


# ##############################################################################
# FIG 50 — PROFILE PLOT ITALY (5 profiles × 29 vars)
# ##############################################################################

cat("--- FIG 50: Profile plot Italy ---\n")

italy_active <- setdiff(all_vars_ordered, c("ac035d4", "ac035d7"))
italy_clust$profile <- factor(as.character(italy_clust$profile),
                               levels = profile_order_italy)

p50 <- plot_profile(italy_std, italy_clust, italy_active,
                    profile_order_italy, "Italy", nrow(italy_clust), 50)
save_fig(p50, "fig_50_profile_plot_italy", w = 13, h = 6.5)


# ##############################################################################
# FIG 51 — PROFILE PLOT SWEDEN (6 profiles × 31 vars)
# ##############################################################################

cat("--- FIG 51: Profile plot Sweden ---\n")

sweden_active <- all_vars_ordered
sweden_clust$profile <- factor(as.character(sweden_clust$profile),
                                levels = profile_order_sweden)

p51 <- plot_profile(sweden_std, sweden_clust, sweden_active,
                    profile_order_sweden, "Sweden", nrow(sweden_clust), 51)
save_fig(p51, "fig_51_profile_plot_sweden", w = 13, h = 6.5)


# ##############################################################################
# SUMMARY
# ##############################################################################

cat("\n============================================================\n")
cat("STEP 15 COMPLETATO.\n")
cat("  2 canonical profile plots salvati in:", fig_dir, "\n")
cat("  Figure totali Step 12+13+14+15: 51\n")
cat("============================================================\n")
