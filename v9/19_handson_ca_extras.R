# ==============================================================================
# STEP 19: HANDS-ON CA COURSE-CANON EXTRAS
# Thesis: "Invisible Profiles" - Bocconi MSc DSBA (course 20570, Prof. Trentini)
#
# Adds the four hands-on Cluster Analysis figures that were skipped in Step 18:
#
#   Fig 70  Profile plot on 6 FA factor scores, Italy       -> 04_italy
#   Fig 71  Profile plot on 6 FA factor scores, Sweden      -> 05_sweden
#   Fig 72  Semi-partial R2 + Pseudo T2 (3 linkages), IT    -> 08_appendix
#   Fig 73  Semi-partial R2 + Pseudo T2 (3 linkages), SE    -> 08_appendix
#
# Rationale
# ---------
# Fig 70/71 complement fig_50/51 (profile plot over 29/31 raw variables) by
# projecting the same five/six profiles onto the six principal-axis factors
# produced in Step 5/6. This is the "profile plot colored by factor block"
# asked by the hands-on CA document, page 13: the line plot is *on factor
# scores* rather than raw variables, and the factor labels are coloured by
# the dominant block of each factor (Health red, Economic green, Digital/
# Social blue, Cognitive purple, Subjective orange). The dominant block is
# read from the loading pattern stored in step5/6_italy_fa_results.rds.
#
# Fig 72/73 are the Q1 hands-on diagnostics for "where to cut the
# dendrogram": Semi-partial R-squared (SPR2) and Pseudo T-squared (PST2)
# curves across k = 2..12 for the three agglomerative linkages (Ward,
# complete, average). SPR2(k -> k-1) is the loss of total R-squared when two
# clusters at level k are merged into one at level k-1; a sharp jump signals
# that a natural grouping is being broken. PST2 (Duda-Hart) rescales the same
# merge by its within-cluster variance, under a normal-cluster null. A local
# maximum in PST2 at k* suggests cutting the tree at k*, so the "right" k is
# where SPR2 shoots up and PST2 peaks.
#
# INPUT  : step2_italy_std.rds, step4_sweden_std.rds,
#          step5_italy_fa_results.rds, step6_sweden_fa_results.rds,
#          step7_italy_with_clusters.rds, step8_sweden_with_clusters.rds
# OUTPUT : fig_70..73 routed by fig_paths.R
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(patchwork)
  library(viridis)
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
fig_dir   <- file.path(data_path, "v9", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Shared helpers: human-readable labels + chapter-subfolder routing.
source(file.path(data_path, "v9", "var_labels.R"))
source(file.path(data_path, "v9", "fig_paths.R"))

cat("============================================================\n")
cat("STEP 19: HANDS-ON CA COURSE-CANON EXTRAS (FIG 70-73)\n")
cat("============================================================\n\n")

# One-time housekeeping: the first draft of fig_70/71 was a profile plot on
# factor scores (wrong interpretation of the hands-on CA). Remove those PNGs
# here so the folder holds only the correct hands-on style figures.
legacy_paths <- c(
  file.path(fig_dir, "04_italy",  "fig_70_profile_on_factors_italy.png"),
  file.path(fig_dir, "05_sweden", "fig_71_profile_on_factors_sweden.png")
)
for (p in legacy_paths) {
  if (file.exists(p)) {
    removed <- file.remove(p)
    if (isTRUE(removed)) cat("  removed legacy figure: ", basename(p), "\n", sep = "")
  }
}



# ##############################################################################
# GLOBAL THEME & PALETTES (identical to Step 12-18)
# ##############################################################################

theme_thesis <- function(base_size = 11) {
  theme_classic(base_size = base_size) +
    theme(
      text              = element_text(family = "sans"),
      plot.title        = element_text(face = "bold", size = base_size + 1, hjust = 0),
      plot.subtitle     = element_text(size = base_size - 1, colour = "grey30"),
      axis.title        = element_text(size = base_size),
      axis.text         = element_text(size = base_size - 1),
      legend.title      = element_text(size = base_size - 1, face = "bold"),
      legend.text       = element_text(size = base_size - 1),
      strip.text        = element_text(face = "bold", size = base_size),
      strip.background  = element_rect(fill = "grey92", colour = NA),
      panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3),
      plot.caption      = element_text(size = base_size - 2, colour = "grey40", hjust = 0)
    )
}

col_italy   <- "#0F4C81"
col_sweden  <- "#8DB9CA"
col_accent  <- "#E07A5F"
profile_palette <- function(n) viridis::viridis(n, option = "D", end = 0.85)

linkage_palette <- c(
  "ward.D2"  = "#1F78B4",
  "complete" = "#6A3D9A",
  "average"  = "#33A02C"
)
linkage_labels <- c(
  "ward.D2"  = "Ward",
  "complete" = "Complete linkage",
  "average"  = "Average linkage"
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
# LOAD DATA
# ##############################################################################

cat("--- Loading pipeline outputs ---\n")
italy_std    <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_std.rds"))
sweden_std   <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_std.rds"))
fa_italy     <- readRDS(file.path(data_path, "v9", "outputs", "step5_italy_fa_results.rds"))
fa_sweden    <- readRDS(file.path(data_path, "v9", "outputs", "step6_sweden_fa_results.rds"))
italy_clust  <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
sweden_clust <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_with_clusters.rds"))

health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                  "sp002_", "sp008_", "sn_size_w9", "social_integration",
                  "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")
all_31       <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

italy_active  <- setdiff(all_31, c("ac035d4", "ac035d7"))
sweden_active <- all_31

X_italy  <- as.matrix(italy_std[,  italy_active])
X_sweden <- as.matrix(sweden_std[, sweden_active])

profile_order_italy  <- c("Fragile Resigned", "Fragile Depressed",
                          "Moderate Isolated", "Traditional Social",
                          "Connected Active")
profile_order_sweden <- c("Fragile", "Social Decline", "Moderate",
                          "Asset Rich", "Wealthy Digital", "Connected Wealthy")

italy_clust$profile  <- factor(as.character(italy_clust$profile),  levels = profile_order_italy)
sweden_clust$profile <- factor(as.character(sweden_clust$profile), levels = profile_order_sweden)

cat(sprintf("  Italy:  %d obs, %d vars active, %d profiles\n",
            nrow(X_italy),  ncol(X_italy),  length(profile_order_italy)))
cat(sprintf("  Sweden: %d obs, %d vars active, %d profiles\n\n",
            nrow(X_sweden), ncol(X_sweden), length(profile_order_sweden)))


# ##############################################################################
# HELPER: ASSIGN EACH VARIABLE TO ITS DOMINANT FA FACTOR
# For each active variable, returns the factor (1..k) on which it has the
# largest absolute loading, along with the value of that loading. Used to
# (a) order variables on the x-axis of fig_70/71 so that variables belonging
# to the same factor sit next to each other, and (b) colour the x-axis tick
# labels by that factor -- which is the canonical hands-on CA layout.
# ##############################################################################

dominant_factor_per_var <- function(fa_obj, active_vars) {
  loadings_mat <- unclass(fa_obj$loadings)
  if (is.null(rownames(loadings_mat)) ||
      any(rownames(loadings_mat) == "")) {
    rownames(loadings_mat) <- active_vars[seq_len(nrow(loadings_mat))]
  }
  abs_l      <- abs(loadings_mat)
  dom_factor <- apply(abs_l, 1, which.max)
  dom_load   <- abs_l[cbind(seq_len(nrow(loadings_mat)), dom_factor)]
  data.frame(
    variable    = rownames(loadings_mat),
    dom_factor  = as.integer(dom_factor),
    dom_loading = as.numeric(dom_load),
    stringsAsFactors = FALSE
  )
}

# Palette for up to 6 FA factors (distinct, high-contrast, colour-blind safe
# enough for a line plot). Sourced from ColorBrewer Dark2 extended with a
# sixth hue so that the same palette serves both 5- and 6-factor solutions.
factor_palette <- c("#D62728",   # F1 red
                    "#1F77B4",   # F2 blue
                    "#2CA02C",   # F3 green
                    "#9467BD",   # F4 purple
                    "#E377C2",   # F5 magenta
                    "#E69F00")   # F6 amber


# ##############################################################################
# FIG 70 & 71 - PROFILE PLOT (HANDS-ON CA STYLE)
# Canonical course 20570 layout: x-axis holds all active variables, grouped
# by dominant FA factor and sorted by |loading| within factor; axis labels
# coloured per factor; one line per profile with a 95% CI ribbon; title
# "Kmeans{k}: Profiles"; vertical dotted lines separate factor blocks.
# ##############################################################################

plot_profile_handson <- function(X, fa_obj, clust_df, active_vars,
                                 profile_order, country_name, country_n,
                                 fig_num) {

  # Align shape
  if (nrow(X) != nrow(clust_df)) {
    stop(sprintf("Standardised matrix (n=%d) and cluster frame (n=%d) have different row counts for %s",
                 nrow(X), nrow(clust_df), country_name))
  }

  # 1) Determine dominant FA factor per variable and sort the x-axis
  var_factor <- dominant_factor_per_var(fa_obj, active_vars)
  var_factor <- var_factor[order(var_factor$dom_factor,
                                 -var_factor$dom_loading), ]
  var_order  <- var_factor$variable
  n_factors  <- max(var_factor$dom_factor)

  # 2) Compute mean z-score and 95% CI per (profile, variable)
  df_wide <- as.data.frame(X)
  df_wide$profile <- factor(as.character(clust_df$profile),
                            levels = profile_order)

  means <- df_wide %>%
    dplyr::filter(!is.na(profile)) %>%
    tidyr::pivot_longer(-profile,
                        names_to = "variable",
                        values_to = "value") %>%
    dplyr::group_by(profile, variable) %>%
    dplyr::summarise(
      mean_z = mean(value, na.rm = TRUE),
      sem    = stats::sd(value, na.rm = TRUE) /
                 sqrt(pmax(sum(!is.na(value)), 1L)),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      ymin     = mean_z - 1.96 * sem,
      ymax     = mean_z + 1.96 * sem,
      variable = factor(variable, levels = var_order)
    )

  # 3) Map each variable to its factor colour (for axis tick labels)
  var_factor_lookup <- setNames(var_factor$dom_factor, var_factor$variable)
  axis_label_colours <- factor_palette[var_factor_lookup[var_order]]

  # 4) Vertical dotted separators between factors
  factor_seq <- unname(var_factor_lookup[var_order])
  boundaries <- which(factor_seq[-1] != factor_seq[-length(factor_seq)]) + 0.5

  # 5) Readable variable labels from the central dictionary
  readable_labels <- relabel(var_order)

  # 6) Caption summarising factor composition
  factor_summary <- sapply(seq_len(n_factors), function(k) {
    vs <- var_factor$variable[var_factor$dom_factor == k]
    if (length(vs) == 0L) return(sprintf("F%d = -", k))
    top <- utils::head(relabel(vs), 3L)
    sprintf("F%d = %s", k, paste(top, collapse = ", "))
  })
  n_profiles <- length(profile_order)

  ggplot(means, aes(x = variable, y = mean_z,
                    colour = profile, fill = profile, group = profile)) +
    geom_hline(yintercept = 0, linetype = "dashed",
               colour = "grey45", linewidth = 0.4) +
    geom_vline(xintercept = boundaries, linetype = "dotted",
               colour = "grey70", linewidth = 0.35) +
    geom_ribbon(aes(ymin = ymin, ymax = ymax),
                alpha = 0.18, linewidth = 0, show.legend = FALSE) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2) +
    scale_colour_manual(values = profile_palette(n_profiles),
                        name = sprintf("Kmeans%d", n_profiles)) +
    scale_fill_manual(values = profile_palette(n_profiles), guide = "none") +
    scale_x_discrete(labels = setNames(readable_labels, var_order)) +
    labs(title    = sprintf("Figure %d. Kmeans%d: Profiles, %s",
                            fig_num, n_profiles, country_name),
         subtitle = sprintf("Mean z-score per profile across %d active variables with 95%% confidence ribbons (n=%s)",
                            nrow(var_factor),
                            format(country_n, big.mark = ",")),
         x = NULL, y = "Mean (standardised)",
         caption = paste0(
           "Variables grouped by dominant FA factor and sorted by |loading| within factor; ",
           "x-axis labels coloured per factor (F1 red, F2 blue, F3 green, F4 purple, F5 magenta, F6 amber). ",
           "Factor composition (top 3 variables per factor): ",
           paste(factor_summary, collapse = "; "), ".")) +
    theme_thesis() +
    theme(legend.position = "right",
          axis.text.x     = element_text(colour = axis_label_colours,
                                         angle = 45, hjust = 1, vjust = 1,
                                         face = "bold", size = 8),
          panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = "grey92",
                                            linewidth = 0.3))
}

cat("--- FIG 70: Kmeans5 profile plot (hands-on CA style), Italy ---\n")
p70 <- plot_profile_handson(X_italy, fa_italy, italy_clust, italy_active,
                            profile_order_italy, "Italy", nrow(X_italy), 70)
save_fig(p70, "fig_70_profile_handson_italy", w = 13, h = 7)

cat("--- FIG 71: Kmeans6 profile plot (hands-on CA style), Sweden ---\n")
p71 <- plot_profile_handson(X_sweden, fa_sweden, sweden_clust, sweden_active,
                            profile_order_sweden, "Sweden", nrow(X_sweden), 71)
save_fig(p71, "fig_71_profile_handson_sweden", w = 13.5, h = 7)


# ##############################################################################
# HELPER: SEMI-PARTIAL R-SQUARED AND PSEUDO T-SQUARED FOR HIERARCHICAL MERGES
# ##############################################################################

compute_hclust_diagnostics <- function(X, hc_method, k_range = 2:12) {
  d  <- dist(X)
  hc <- hclust(d, method = hc_method)

  # Total SS across all variables
  total_ss <- sum(apply(X, 2, function(col) sum((col - mean(col))^2)))

  within_ss_at_k <- function(k) {
    cl <- cutree(hc, k = k)
    sum(vapply(unique(cl), function(c) {
      rows <- which(cl == c)
      if (length(rows) < 2L) return(0)
      Xc <- X[rows, , drop = FALSE]
      sum(apply(Xc, 2, function(col) sum((col - mean(col))^2)))
    }, numeric(1)))
  }

  ks  <- sort(unique(k_range))
  wss <- vapply(ks, within_ss_at_k, numeric(1))
  r2  <- 1 - wss / total_ss

  # SPR2(k) = fall in R2 going from k clusters to k-1 = (wss_{k-1} - wss_k)/total_ss
  # We align SPR2 with the "upper" endpoint of the merge (i.e. the k from which
  # we are about to merge a pair), so SPR2 at k = R2(k) - R2(k-1).
  spr2 <- rep(NA_real_, length(ks))
  for (i in seq_along(ks)) {
    k <- ks[i]
    if ((k - 1L) %in% ks) {
      wss_km1 <- wss[match(k - 1L, ks)]
      spr2[i] <- (wss_km1 - wss[i]) / total_ss
    }
  }

  # Pseudo T2 (Duda-Hart) for the merge k -> k-1: identify which two clusters
  # at level k collapsed into one cluster at level k-1, then
  #   PST2 = ((Wc - Wa - Wb) / (Wa + Wb)) * (na + nb - 2)
  pst2 <- rep(NA_real_, length(ks))
  for (i in seq_along(ks)) {
    k <- ks[i]
    if (!((k - 1L) %in% ks)) next
    cl_k   <- cutree(hc, k = k)
    cl_km1 <- cutree(hc, k = k - 1L)
    xt <- table(cl_k, cl_km1)
    # The column (cluster of level k-1) with two nonzero rows is the merged pair
    nz_per_col <- colSums(xt > 0)
    merge_col  <- which(nz_per_col == 2L)
    if (length(merge_col) != 1L) next
    ab_rows    <- which(xt[, merge_col] > 0)
    if (length(ab_rows) != 2L) next
    a_id <- as.integer(rownames(xt)[ab_rows[1]])
    b_id <- as.integer(rownames(xt)[ab_rows[2]])

    rows_a <- which(cl_k == a_id)
    rows_b <- which(cl_k == b_id)
    na <- length(rows_a); nb <- length(rows_b)
    if (na < 1L || nb < 1L || (na + nb) < 3L) next

    Wa <- if (na < 2L) 0 else sum(apply(X[rows_a, , drop = FALSE], 2,
                                        function(c) sum((c - mean(c))^2)))
    Wb <- if (nb < 2L) 0 else sum(apply(X[rows_b, , drop = FALSE], 2,
                                        function(c) sum((c - mean(c))^2)))
    rows_c <- c(rows_a, rows_b)
    Wc <- sum(apply(X[rows_c, , drop = FALSE], 2,
                     function(c) sum((c - mean(c))^2)))
    denom <- (Wa + Wb)
    if (denom <= .Machine$double.eps) next
    pst2[i] <- ((Wc - Wa - Wb) / denom) * (na + nb - 2L)
  }

  data.frame(method = hc_method, k = ks, R2 = r2,
             SPR2 = spr2, PST2 = pst2,
             stringsAsFactors = FALSE)
}


# ##############################################################################
# FIG 72 & 73 - SEMI-PARTIAL R2 + PSEUDO T2 PER LINKAGE
# ##############################################################################

plot_spr2_pst2 <- function(X, k_chosen, country_name, fig_num,
                           k_range = 2:12) {
  cat(sprintf("    computing diagnostics on n=%d for 3 linkages...\n", nrow(X)))
  diag_ward     <- compute_hclust_diagnostics(X, "ward.D2",  k_range)
  diag_complete <- compute_hclust_diagnostics(X, "complete", k_range)
  diag_average  <- compute_hclust_diagnostics(X, "average",  k_range)

  all_diag <- bind_rows(diag_ward, diag_complete, diag_average) %>%
    mutate(method = factor(method,
                           levels = c("ward.D2", "complete", "average"),
                           labels = linkage_labels[c("ward.D2", "complete", "average")]))

  legend_vals <- setNames(unname(linkage_palette[c("ward.D2", "complete", "average")]),
                          linkage_labels[c("ward.D2", "complete", "average")])

  p_left <- ggplot(all_diag, aes(x = k, y = SPR2,
                                 colour = method, group = method)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.8) +
    geom_vline(xintercept = k_chosen, linetype = "dashed",
               colour = col_accent, alpha = 0.6) +
    scale_colour_manual(values = legend_vals, name = "Linkage") +
    scale_x_continuous(breaks = k_range) +
    labs(subtitle = "Semi-partial R\u00b2 at each merge",
         x = "Number of clusters (k)",
         y = "SPR\u00b2 = R\u00b2(k) - R\u00b2(k-1)") +
    theme_thesis() +
    theme(legend.position = "top")

  p_right <- ggplot(all_diag, aes(x = k, y = PST2,
                                  colour = method, group = method)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.8) +
    geom_vline(xintercept = k_chosen, linetype = "dashed",
               colour = col_accent, alpha = 0.6) +
    scale_colour_manual(values = legend_vals, name = "Linkage") +
    scale_x_continuous(breaks = k_range) +
    labs(subtitle = "Pseudo T\u00b2 (Duda-Hart) for the merge k -> k-1",
         x = "Number of clusters (k)",
         y = "PST\u00b2") +
    theme_thesis() +
    theme(legend.position = "top")

  (p_left | p_right) +
    plot_layout(guides = "collect") +
    plot_annotation(
      title = sprintf("Figure %d. Hierarchical cut-off diagnostics, %s",
                      fig_num, country_name),
      subtitle = sprintf("Semi-partial R\u00b2 and Pseudo T\u00b2 for Ward, complete and average linkage; k = %d..%d; dashed line marks k = %d retained",
                         min(k_range), max(k_range), k_chosen),
      caption  = "A peak (or sharp rise) in SPR\u00b2 or PST\u00b2 at k = k* signals that collapsing two clusters at that level destroys a well-separated group, which is the classical Duda-Hart criterion for stopping the merge process at k*.",
      theme    = theme_thesis()
    ) &
    theme(legend.position = "top")
}

cat("--- FIG 72: SPR2 + PST2 by linkage, Italy ---\n")
p72 <- plot_spr2_pst2(X_italy,  k_chosen = 5, "Italy",  72)
save_fig(p72, "fig_72_spr2_pst2_italy",  w = 13, h = 6)

cat("--- FIG 73: SPR2 + PST2 by linkage, Sweden ---\n")
p73 <- plot_spr2_pst2(X_sweden, k_chosen = 6, "Sweden", 73)
save_fig(p73, "fig_73_spr2_pst2_sweden", w = 13, h = 6)


# ##############################################################################
# SUMMARY
# ##############################################################################

cat("\n============================================================\n")
cat("STEP 19 COMPLETE -- 4 hands-on CA extras generated\n")
cat("============================================================\n")
cat("  fig_70_profile_handson_italy.png      Kmeans5 profile plot (hands-on style) IT -> 04_italy\n")
cat("  fig_71_profile_handson_sweden.png     Kmeans6 profile plot (hands-on style) SE -> 05_sweden\n")
cat("  fig_72_spr2_pst2_italy.png            SPR\u00b2 + PST\u00b2 by linkage IT  -> 08_appendix\n")
cat("  fig_73_spr2_pst2_sweden.png           SPR\u00b2 + PST\u00b2 by linkage SE  -> 08_appendix\n\n")
cat("Saved under:", fig_dir, "\n")
