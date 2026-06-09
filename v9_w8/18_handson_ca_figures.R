# ==============================================================================
# STEP 18: HANDS-ON CLUSTER ANALYSIS COURSE-CANON FIGURES
# Thesis: "Invisible Profiles" - Bocconi MSc DSBA (course 20570, Prof. Trentini)
#
# Adds six figures that replicate the diagnostic plots from the Piccareta &
# Trentini "Hands-on Cluster Analysis" (May 2025) which are missing from
# Step 12, 13, 14 and the PCA/FA add-ons:
#
#   Fig 64  Cluster quality indexes across algorithms, Italy (kmeans/ward/complete/avg)
#   Fig 65  Cluster quality indexes across algorithms, Sweden
#   Fig 66  Variable-specific R-squared heatmap across solutions, Italy
#   Fig 67  Variable-specific R-squared heatmap across solutions, Sweden
#   Fig 68  Boxplots faceted by variable (x = cluster), Italy
#   Fig 69  Boxplots faceted by variable (x = cluster), Sweden
#
# The script addresses the hands-on canonical outputs for Q1 (global/variables
# specific performance across algorithms) and Q3 (cluster description).
#
# Complements existing figures:
#   - fig_22/23 (quality indexes, kmeans only) -> fig_64/65 adds 3 extra algorithms
#   - fig_47/48 (boxplots faceted by cluster)  -> fig_68/69 mirror: facet by variable
#
# INPUT : v9/outputs/step2_italy_std.rds, v9/outputs/step4_sweden_std.rds
#         v9/outputs/step7_italy_with_clusters.rds, v9/outputs/step8_sweden_with_clusters.rds
# OUTPUT: v9/figures/fig_64_*.png ... fig_69_*.png
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(cluster)
  library(patchwork)
  if (!requireNamespace("fpc", quietly = TRUE)) install.packages("fpc", quiet = TRUE)
  library(fpc)
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
fig_dir   <- file.path(data_path, "v9", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Central dictionary of human-readable labels for all 31 active variables.
# Exposes: var_labels (short), var_labels_scale (with measurement scale),
# var_block, var_block_colours, and relabel() / block_of() helpers.
source(file.path(data_path, "v9", "var_labels.R"))
# Chapter-subfolder routing for save_fig().
source(file.path(data_path, "v9", "fig_paths.R"))

cat("============================================================\n")
cat("STEP 18: HANDS-ON CA COURSE-CANON FIGURES\n")
cat("============================================================\n\n")


# ##############################################################################
# GLOBAL THEME & PALETTE (identical to Step 12/13/16/17)
# ##############################################################################

theme_thesis <- function(base_size = 11) {
  theme_classic(base_size = base_size) +
    theme(
      text          = element_text(family = "sans"),
      plot.title    = element_text(face = "bold", size = base_size + 1, hjust = 0),
      plot.subtitle = element_text(size = base_size - 1, colour = "grey30"),
      axis.title    = element_text(size = base_size),
      axis.text     = element_text(size = base_size - 1),
      legend.title  = element_text(size = base_size - 1, face = "bold"),
      legend.text   = element_text(size = base_size - 1),
      strip.text    = element_text(face = "bold", size = base_size),
      strip.background = element_rect(fill = "grey92", colour = NA),
      panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3),
      plot.caption  = element_text(size = base_size - 2, colour = "grey40", hjust = 0)
    )
}

col_italy    <- "#0F4C81"
col_sweden   <- "#8DB9CA"
col_accent   <- "#E07A5F"
col_neutral  <- "grey40"
profile_palette <- function(n) viridis::viridis(n, option = "D", end = 0.85)

# Four-algorithm palette, inspired by the hands-on CA colour scheme
alg_palette <- c(
  kmeans      = "#D73027",   # red
  ward.D2     = "#1F78B4",   # blue
  complete    = "#6A3D9A",   # purple
  average     = "#33A02C"    # green
)
alg_labels <- c(
  kmeans      = "k-means",
  ward.D2     = "Ward",
  complete    = "Complete linkage",
  average     = "Average linkage"
)

save_fig <- function(p, name, w = 7, h = 5, also_pdf = FALSE) {
  out_dir <- ensure_fig_dir(fig_dir, name)
  base    <- file.path(out_dir, name)
  ggsave(paste0(base, ".png"), p, width = w, height = h, dpi = 300, bg = "white")
  if (also_pdf) ggsave(paste0(base, ".pdf"), p, width = w, height = h, bg = "white")
  cat(sprintf("    \u2713 %s  (%.1fx%.1f in)  -> %s/\n",
              name, w, h, basename(out_dir)))
}


# ##############################################################################
# LOAD DATA AND DEFINE ACTIVE VARIABLES
# ##############################################################################

cat("--- Loading pipeline outputs ---\n")
italy_std   <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_std.rds"))
sweden_std  <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_std.rds"))
italy_clust <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
sweden_clust<- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_with_clusters.rds"))
cat(sprintf("  Italy:  %d rows\n",  nrow(italy_std)))
cat(sprintf("  Sweden: %d rows\n\n", nrow(sweden_std)))

health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")
all_31       <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

italy_active  <- setdiff(all_31, c("ac035d4", "ac035d7"))   # 29 vars
sweden_active <- all_31                                      # 31 vars

X_italy  <- as.matrix(italy_std[,  italy_active])
X_sweden <- as.matrix(sweden_std[, sweden_active])

profile_order_italy  <- c("Fragile Resigned", "Fragile Depressed",
                          "Moderate Isolated", "Traditional Social",
                          "Connected Active")
profile_order_sweden <- c("Fragile", "Social Decline", "Moderate",
                          "Asset Rich", "Wealthy Digital", "Connected Wealthy")

italy_clust$profile  <- factor(as.character(italy_clust$profile),  levels = profile_order_italy)
sweden_clust$profile <- factor(as.character(sweden_clust$profile), levels = profile_order_sweden)


# ##############################################################################
# HELPER: MULTI-ALGORITHM QUALITY INDEXES
# Adapted from Step 13 fig_22/23 to accept 4 algorithms simultaneously
# ##############################################################################

compute_quality_multi_alg <- function(X, k_range = 2:12, seed = 42, subsample_size = 1000) {
  # Subsample for speed (cluster.stats on full n is slow)
  set.seed(seed)
  n <- nrow(X)
  idx   <- if (n > subsample_size) sample(seq_len(n), subsample_size) else seq_len(n)
  X_sub <- X[idx, ]
  d_sub <- dist(X_sub)

  # Pre-compute hierarchical clusterings on the subsample once per linkage
  hc_cache <- list(
    ward.D2   = hclust(d_sub, method = "ward.D2"),
    complete  = hclust(d_sub, method = "complete"),
    average   = hclust(d_sub, method = "average")
  )

  # Safely extract a scalar numeric from a cluster.stats slot (returns NA
  # if the slot is NULL, empty, or non-numeric — some versions of fpc omit
  # pearsongamma or dunn for certain partitions)
  safe_num <- function(x) {
    if (is.null(x) || length(x) == 0) return(NA_real_)
    v <- suppressWarnings(as.numeric(x[1]))
    if (length(v) == 0 || !is.finite(v)) NA_real_ else v
  }

  algs <- c("kmeans", "ward.D2", "complete", "average")
  results <- list()

  for (alg in algs) {
    for (k in k_range) {
      if (alg == "kmeans") {
        set.seed(seed + k)
        cl <- kmeans(X_sub, centers = k, nstart = 30, iter.max = 100)$cluster
      } else {
        cl <- cutree(hc_cache[[alg]], k = k)
      }
      # Guard against degenerate partitions
      if (length(unique(cl)) < 2) next
      stats <- tryCatch(
        suppressWarnings(fpc::cluster.stats(d_sub, cl)),
        error = function(e) NULL
      )
      if (is.null(stats)) next

      within_ss  <- safe_num(stats$within.cluster.ss)
      between_ss <- safe_num(stats$between.cluster.ss)
      r2         <- if (is.na(within_ss) || is.na(between_ss)) NA_real_
                    else 1 - within_ss / (within_ss + between_ss)

      results[[length(results) + 1]] <- data.frame(
        algorithm  = alg,
        k          = k,
        R2         = r2,
        Silhouette = safe_num(stats$avg.silwidth),
        PseudoF    = safe_num(stats$ch),
        Dunn       = safe_num(stats$dunn),
        DB         = safe_num(stats$wb.ratio),       # surrogate; lower = better
        Ptbiserial = safe_num(stats$pearsongamma),
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(results) == 0) {
    stop("compute_quality_multi_alg: no partition returned valid statistics")
  }
  do.call(rbind, results)
}


# ##############################################################################
# FIG 64 & 65 - CLUSTER QUALITY INDEXES ACROSS ALGORITHMS
# Replicates hands-on CA page 4 (R2, PseudoF, Silhouette, DB, Dunn, Ptbiserial
# across k with four algorithm lines)
# ##############################################################################

plot_quality_multi_alg <- function(qi, k_chosen, country_name, fig_num) {
  df <- qi %>%
    pivot_longer(c(R2, PseudoF, Silhouette, DB, Dunn, Ptbiserial),
                 names_to = "metric", values_to = "value") %>%
    mutate(
      metric = factor(metric,
                      levels = c("R2", "PseudoF", "Silhouette", "DB", "Dunn", "Ptbiserial"),
                      labels = c("R\u00b2 (higher = better)",
                                 "Pseudo-F / CH (higher = better)",
                                 "Silhouette (higher = better)",
                                 "wb.ratio (lower = better)",
                                 "Dunn index (higher = better)",
                                 "Pearson-gamma (higher = better)")),
      algorithm = factor(algorithm,
                         levels = c("kmeans", "ward.D2", "complete", "average"),
                         labels = alg_labels[c("kmeans", "ward.D2", "complete", "average")])
    )

  ggplot(df, aes(x = k, y = value, colour = algorithm, group = algorithm)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.8) +
    geom_vline(xintercept = k_chosen, linetype = "dashed",
               colour = col_accent, alpha = 0.6) +
    facet_wrap(~ metric, scales = "free_y", ncol = 3) +
    scale_colour_manual(values = setNames(unname(alg_palette[c("kmeans", "ward.D2", "complete", "average")]),
                                           alg_labels[c("kmeans", "ward.D2", "complete", "average")]),
                        name = "Algorithm") +
    scale_x_continuous(breaks = 2:12) +
    labs(title = sprintf("Figure %d. Cluster quality indexes across algorithms, %s",
                         fig_num, country_name),
         subtitle = sprintf("Six internal validity criteria for k = 2..12; dashed line marks k = %d retained; k-means, Ward, complete and average linkage compared",
                            k_chosen),
         x = "Number of clusters (k)", y = NULL,
         caption = "Computed on a 1,000-observation subsample via fpc::cluster.stats; wb.ratio proxies the Davies-Bouldin index (lower values indicate tighter, better-separated clusters).") +
    theme_thesis() +
    theme(legend.position = "top")
}

cat("--- FIG 64: Multi-algorithm quality indexes Italy ---\n")
qi_italy  <- compute_quality_multi_alg(X_italy,  k_range = 2:12)
p64 <- plot_quality_multi_alg(qi_italy,  k_chosen = 5, "Italy",  64)
save_fig(p64, "fig_64_cluster_quality_multi_alg_italy",  w = 12, h = 7)

cat("--- FIG 65: Multi-algorithm quality indexes Sweden ---\n")
qi_sweden <- compute_quality_multi_alg(X_sweden, k_range = 2:12)
p65 <- plot_quality_multi_alg(qi_sweden, k_chosen = 6, "Sweden", 65)
save_fig(p65, "fig_65_cluster_quality_multi_alg_sweden", w = 12, h = 7)


# ##############################################################################
# HELPER: VARIABLE-SPECIFIC R-SQUARED ACROSS SOLUTIONS
# ##############################################################################

compute_varspec_r2 <- function(X, k_range = 4:7, seed = 42) {
  # Compute R-squared per variable = 1 - within-SS / total-SS for each
  # (algorithm, k) combination, on the full sample. Hierarchical clusterings
  # are pre-computed once per linkage.
  d <- dist(X)
  hc_cache <- list(
    ward.D2  = hclust(d, method = "ward.D2"),
    complete = hclust(d, method = "complete"),
    average  = hclust(d, method = "average")
  )

  algs <- c("kmeans", "ward.D2", "complete", "average")
  alg_code <- c(kmeans = "K", ward.D2 = "W", complete = "C", average = "A")

  r2_list <- list()
  var_names <- colnames(X)

  for (alg in algs) {
    for (k in k_range) {
      if (alg == "kmeans") {
        set.seed(seed + k)
        cl <- kmeans(X, centers = k, nstart = 30, iter.max = 100)$cluster
      } else {
        cl <- cutree(hc_cache[[alg]], k = k)
      }
      if (length(unique(cl)) < 2) next
      r2 <- vapply(seq_len(ncol(X)), function(j) {
        xj <- X[, j]
        total_ss  <- sum((xj - mean(xj))^2)
        within_ss <- sum(vapply(split(xj, cl),
                                 function(x) sum((x - mean(x))^2),
                                 numeric(1)))
        1 - within_ss / total_ss
      }, numeric(1))
      names(r2) <- var_names
      r2_list[[paste0(alg_code[alg], k)]] <- r2
    }
  }

  mat <- do.call(cbind, r2_list)
  # Column order: W4..Wmax, K4..Kmax, C4..Cmax, A4..Amax
  ordered_cols <- c(
    paste0("W", k_range),
    paste0("K", k_range),
    paste0("C", k_range),
    paste0("A", k_range)
  )
  ordered_cols <- intersect(ordered_cols, colnames(mat))
  mat[, ordered_cols, drop = FALSE]
}


# ##############################################################################
# FIG 66 & 67 - VARIABLE-SPECIFIC R-SQUARED HEATMAP
# Replicates hands-on CA page 6 "Comparison of solutions" heatmap
# ##############################################################################

plot_varspec_r2 <- function(mat, k_chosen, country_col, country_name, fig_num,
                            var_blocks) {
  # Long-format
  df <- as.data.frame(mat) %>%
    tibble::rownames_to_column("variable") %>%
    pivot_longer(-variable, names_to = "solution", values_to = "r2") %>%
    mutate(
      alg_letter = substr(solution, 1, 1),
      k          = as.integer(sub("[A-Z]", "", solution)),
      alg_label  = factor(alg_letter,
                          levels = c("W", "K", "C", "A"),
                          labels = c("Ward", "k-means", "Complete", "Average")),
      solution   = factor(solution, levels = colnames(mat)),
      label_txt  = sprintf("%.2f", r2)
    )
  # Attach block info to colour-code y-axis labels
  block_lookup <- unlist(lapply(names(var_blocks), function(b) {
    setNames(rep(b, length(var_blocks[[b]])), var_blocks[[b]])
  }))
  df$block <- factor(block_lookup[df$variable], levels = names(var_blocks))
  df$variable <- factor(df$variable, levels = rev(unname(unlist(var_blocks))))

  # Block palette for y-axis tick colours (shared with profile plots via
  # var_block_colours in var_labels.R). Here Digital/Social is abbreviated
  # to "Digital" in the block_lookup produced from var_blocks to match the
  # facet headers already used in fig_50/51.
  block_colours <- c(
    Health     = unname(var_block_colours["Health"]),
    Economy    = unname(var_block_colours["Economic"]),
    Digital    = unname(var_block_colours["Digital/Social"]),
    Cognitive  = unname(var_block_colours["Cognitive"]),
    Subjective = unname(var_block_colours["Subjective"])
  )
  y_levels   <- levels(df$variable)
  y_blocks   <- block_lookup[y_levels]
  y_colours  <- block_colours[y_blocks]
  # Replace the technical variable names with the extended (with-scale) labels
  y_text_lab <- relabel(y_levels, style = "scale")

  # Vertical separators between algorithms
  n_k <- length(unique(df$k))
  vline_positions <- seq(n_k, by = n_k, length.out = 3) + 0.5

  ggplot(df, aes(x = solution, y = variable, fill = r2)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    geom_text(aes(label = label_txt, colour = r2 > 0.25),
              size = 2.3, show.legend = FALSE) +
    geom_vline(xintercept = vline_positions, colour = "grey30",
               linewidth = 0.4) +
    facet_grid(~ alg_label, scales = "free_x", space = "free_x") +
    scale_fill_gradient(low = "#F7FBFF", high = country_col, limits = c(0, 0.6),
                        oob = squish, name = "R\u00b2") +
    scale_colour_manual(values = c(`FALSE` = "grey20", `TRUE` = "white")) +
    scale_y_discrete(labels = setNames(y_text_lab, y_levels)) +
    labs(title = sprintf("Figure %d. Variable-specific R\u00b2 across clustering solutions, %s",
                         fig_num, country_name),
         subtitle = sprintf("Rows: %d active variables grouped by dimension; columns: 4 algorithms x k = %d..%d; dashed-style separators mark algorithm boundaries",
                            nrow(mat), min(as.integer(sub("[A-Z]", "", colnames(mat)))),
                            max(as.integer(sub("[A-Z]", "", colnames(mat))))),
         x = NULL, y = NULL,
         caption = "R\u00b2 = 1 - within-cluster SS / total SS. Variables whose R\u00b2 saturates as k grows are well discriminated by the partition; variables stuck at low R\u00b2 are the same across methods and solutions, signalling they carry no clustering signal. Measurement scales are given in parentheses next to each variable label; y-axis labels coloured by dimension (Health red, Economic green, Digital/Social blue, Cognitive purple, Subjective orange).") +
    theme_thesis() +
    theme(panel.grid  = element_blank(),
          axis.text.y = element_text(size = 8, colour = y_colours),
          axis.text.x = element_text(size = 8),
          panel.spacing.x = unit(0.4, "lines"),
          strip.background = element_rect(fill = "grey85", colour = NA))
}

var_blocks_italy <- list(
  Health     = intersect(health_vars,  italy_active),
  Economy    = intersect(econ_vars,    italy_active),
  Digital    = intersect(digital_vars, italy_active),
  Cognitive  = intersect(cog_vars,     italy_active),
  Subjective = intersect(subj_vars,    italy_active)
)
var_blocks_sweden <- list(
  Health     = intersect(health_vars,  sweden_active),
  Economy    = intersect(econ_vars,    sweden_active),
  Digital    = intersect(digital_vars, sweden_active),
  Cognitive  = intersect(cog_vars,     sweden_active),
  Subjective = intersect(subj_vars,    sweden_active)
)

cat("--- FIG 66: Variable-specific R-squared Italy ---\n")
vr_italy  <- compute_varspec_r2(X_italy,  k_range = 4:7)
p66 <- plot_varspec_r2(vr_italy,  k_chosen = 5, col_italy,  "Italy",  66,
                       var_blocks_italy)
save_fig(p66, "fig_66_varspec_r2_italy",  w = 12, h = 9)

cat("--- FIG 67: Variable-specific R-squared Sweden ---\n")
vr_sweden <- compute_varspec_r2(X_sweden, k_range = 4:7)
p67 <- plot_varspec_r2(vr_sweden, k_chosen = 6, col_sweden, "Sweden", 67,
                       var_blocks_sweden)
save_fig(p67, "fig_67_varspec_r2_sweden", w = 12, h = 9.5)


# ##############################################################################
# FIG 68 & 69 - BOXPLOTS FACETED BY VARIABLE
# Replicates hands-on CA page 12 bottom ("Boxplots by variable")
# ##############################################################################

plot_boxplots_by_variable <- function(X, clust_df, profile_order, country_name,
                                      country_col, fig_num, var_blocks) {
  var_names <- colnames(X)
  block_lookup <- unlist(lapply(names(var_blocks), function(b) {
    setNames(rep(b, length(var_blocks[[b]])), var_blocks[[b]])
  }))

  df_long <- as.data.frame(X) %>%
    mutate(profile = clust_df$profile) %>%
    pivot_longer(-profile, names_to = "variable", values_to = "value") %>%
    filter(!is.na(profile)) %>%
    mutate(
      profile  = factor(as.character(profile), levels = profile_order),
      block    = factor(block_lookup[variable], levels = names(var_blocks)),
      variable = factor(variable, levels = unname(unlist(var_blocks)))
    )

  n_profiles <- length(profile_order)

  # Human-readable facet strip labels: short var_labels keyed on the technical
  # variable name so factor levels stay stable but the rendered text is legible.
  facet_lab <- as_labeller(relabel(levels(df_long$variable)) %>%
                             setNames(levels(df_long$variable)))

  ggplot(df_long, aes(x = profile, y = value, fill = profile)) +
    geom_hline(yintercept = 0, linetype = "dotted", colour = "grey60",
               linewidth = 0.3) +
    geom_boxplot(outlier.size = 0.5, outlier.alpha = 0.4,
                 linewidth = 0.25) +
    facet_wrap(~ variable, ncol = 6, scales = "free_y", labeller = facet_lab) +
    scale_fill_manual(values = profile_palette(n_profiles), name = "Profile") +
    labs(title = sprintf("Figure %d. Distribution of active variables by profile, %s",
                          fig_num, country_name),
         subtitle = sprintf("Each panel: one standardised active variable on the y-axis, %d profiles on the x-axis; dotted line marks the country grand mean (z = 0)",
                            n_profiles),
         x = NULL, y = "Standardised value",
         caption = "Panels ordered by dimension block (Health, Economy, Digital/Social, Cognitive, Subjective). Complements figure 47/48 which facets by profile; this layout is the more effective reading when the question is \"for variable X, which profile scores highest?\".") +
    theme_thesis() +
    theme(legend.position  = "top",
          axis.text.x      = element_blank(),
          axis.ticks.x     = element_blank(),
          strip.text       = element_text(size = 8),
          panel.spacing    = unit(0.3, "lines"))
}

cat("--- FIG 68: Boxplots by variable Italy ---\n")
p68 <- plot_boxplots_by_variable(X_italy,  italy_clust,  profile_order_italy,
                                  "Italy",  col_italy,  68, var_blocks_italy)
save_fig(p68, "fig_68_boxplots_by_variable_italy",  w = 13, h = 11)

cat("--- FIG 69: Boxplots by variable Sweden ---\n")
p69 <- plot_boxplots_by_variable(X_sweden, sweden_clust, profile_order_sweden,
                                  "Sweden", col_sweden, 69, var_blocks_sweden)
save_fig(p69, "fig_69_boxplots_by_variable_sweden", w = 13, h = 11.5)


# ##############################################################################
# SUMMARY
# ##############################################################################

cat("\n============================================================\n")
cat("STEP 18 COMPLETE -- 6 course-canon CA figures generated\n")
cat("============================================================\n")
cat("  fig_64_cluster_quality_multi_alg_italy.png   4 algorithms x 6 indexes IT\n")
cat("  fig_65_cluster_quality_multi_alg_sweden.png  4 algorithms x 6 indexes SE\n")
cat("  fig_66_varspec_r2_italy.png                   variable R\u00b2 across solutions IT\n")
cat("  fig_67_varspec_r2_sweden.png                  variable R\u00b2 across solutions SE\n")
cat("  fig_68_boxplots_by_variable_italy.png         boxplots facet-by-var IT\n")
cat("  fig_69_boxplots_by_variable_sweden.png        boxplots facet-by-var SE\n\n")
cat("Saved to:", fig_dir, "\n")
