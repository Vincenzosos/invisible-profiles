# ==============================================================================
# STEP 14: GAP FIGURES vs COURSE 20570 HANDS-ON CANON
# Thesis: "Invisible Profiles" — Bocconi MSc DSBA
#
# Aggiunge 10 figure residue per coprire gap rispetto ai 3 hands-on del corso
# Trentini (PCA / Factor Analysis / Cluster Analysis). Stile identico a
# Step 12/13 (theme_thesis, viridis palette, PNG 300 DPI).
#
#   Fig 40  Global scree plot (full correlation matrix) IT + SE      (Ch 4-5)
#   Fig 41  FA scores scatter PA1xPA2 colored by profile — Italy     (Ch 4)
#   Fig 42  FA scores scatter PA1xPA2 colored by profile — Sweden    (Ch 5)
#   Fig 43  FA scores scatter PA3xPA4 — Italy                         (Ch 4)
#   Fig 44  FA scores scatter PA3xPA4 — Sweden                        (Ch 5)
#   Fig 45  Dendrogram comparison (ward, average, complete) — Italy   (App)
#   Fig 46  Dendrogram comparison — Sweden                            (App)
#   Fig 47  Boxplots key variables x profile — Italy (9-panel)        (Ch 4)
#   Fig 48  Boxplots key variables x profile — Sweden                 (Ch 5)
#   Fig 49  Silhouette boxplot per cluster — IT + SE side-by-side     (Ch 6)
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(cluster)
  library(patchwork)
  library(viridis)
  library(ggdendro)
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
fig_dir   <- file.path(data_path, "v9", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Human-readable variable labels (shared with Step 12/13/15/16/17/18).
source(file.path(data_path, "v9", "var_labels.R"))
# Chapter-subfolder routing for save_fig().
source(file.path(data_path, "v9", "fig_paths.R"))

cat("============================================================\n")
cat("STEP 14: GAP FIGURES (CANON HANDS-ON)\n")
cat("============================================================\n\n")

# ---- Theme + helpers (identici a Step 12/13) ----
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
col_italy  <- "#0F4C81"
col_sweden <- "#8DB9CA"
col_accent <- "#E07A5F"
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
fa_italy     <- readRDS(file.path(data_path, "v9", "outputs", "step5_italy_fa_results.rds"))
fa_sweden    <- readRDS(file.path(data_path, "v9", "outputs", "step6_sweden_fa_results.rds"))
cat("  ...loaded\n\n")

health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                  "sp002_", "sp008_", "sn_size_w9", "social_integration",
                  "ac035d4", "ac035d7")
cog_vars  <- c("fluency", "memory", "orienti")
subj_vars <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")
all_31    <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

italy_active  <- setdiff(all_31, c("ac035d4", "ac035d7"))
sweden_active <- all_31

X_italy  <- as.matrix(italy_std[, italy_active])
X_sweden <- as.matrix(sweden_std[, sweden_active])

profile_order_italy  <- c("Fragile Resigned", "Fragile Depressed",
                          "Moderate Isolated", "Traditional Social",
                          "Connected Active")
profile_order_sweden <- c("Fragile", "Social Decline", "Moderate",
                          "Asset Rich", "Wealthy Digital", "Connected Wealthy")

italy_clust$profile  <- factor(italy_clust$profile,  levels = profile_order_italy)
sweden_clust$profile <- factor(sweden_clust$profile, levels = profile_order_sweden)


# ##############################################################################
# FIG 40 — GLOBAL SCREE PLOT IT + SE (full correlation matrix)
# ##############################################################################

cat("--- FIG 40: Global scree plot IT + SE ---\n")

eig_it <- eigen(cor(X_italy))$values
eig_se <- eigen(cor(X_sweden))$values

scree_global <- bind_rows(
  data.frame(country = "Italy",  k = seq_along(eig_it), eigenvalue = eig_it),
  data.frame(country = "Sweden", k = seq_along(eig_se), eigenvalue = eig_se)
) %>%
  mutate(
    kaiser = eigenvalue > 1,
    country = factor(country, levels = c("Italy", "Sweden"))
  )

# Numeri di PC sopra Kaiser
n_kaiser <- scree_global %>% group_by(country) %>%
  summarise(n_kaiser = sum(kaiser), .groups = "drop")

p40 <- ggplot(scree_global, aes(x = k, y = eigenvalue, colour = country)) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2) +
  scale_colour_manual(values = c(Italy = col_italy, Sweden = col_sweden)) +
  scale_x_continuous(breaks = seq(0, 35, 5)) +
  labs(title = "Figure 40. Global scree plot, full correlation matrix",
       subtitle = sprintf("Italy: %d PCs above Kaiser threshold; Sweden: %d PCs",
                           n_kaiser$n_kaiser[1], n_kaiser$n_kaiser[2]),
       x = "Principal component", y = "Eigenvalue",
       caption = "Full eigendecomposition of the 29 (Italy) / 31 (Sweden) standardized analytical variables.") +
  theme_thesis() +
  theme(legend.position = "top")

save_fig(p40, "fig_40_global_scree", w = 9, h = 5.5)


# ##############################################################################
# FIG 41-44 — FA SCORES SCATTER PA1xPA2 and PA3xPA4
# ##############################################################################

plot_fa_scatter <- function(scores, clust_df, profile_order, country_name, x_pa, y_pa,
                             x_label, y_label, fig_num, country_col) {
  if (ncol(scores) < max(x_pa, y_pa)) {
    cat(sprintf("    (skip fig %d: scores have only %d cols)\n", fig_num, ncol(scores)))
    return(NULL)
  }
  df <- data.frame(
    PA_x = scores[, x_pa],
    PA_y = scores[, y_pa],
    profile = clust_df$profile
  )
  df <- df[!is.na(df$PA_x) & !is.na(df$PA_y), ]
  df$profile <- factor(as.character(df$profile), levels = profile_order)

  cent <- df %>% group_by(profile) %>%
    summarise(PA_x = mean(PA_x), PA_y = mean(PA_y), .groups = "drop")

  n_levels <- length(profile_order)
  ggplot(df, aes(x = PA_x, y = PA_y, colour = profile)) +
    geom_hline(yintercept = 0, linetype = "dotted", colour = "grey60", linewidth = 0.3) +
    geom_vline(xintercept = 0, linetype = "dotted", colour = "grey60", linewidth = 0.3) +
    geom_point(alpha = 0.35, size = 1.2) +
    geom_point(data = cent, aes(x = PA_x, y = PA_y, fill = profile),
               size = 4, shape = 23, colour = "black", stroke = 0.5) +
    scale_colour_manual(values = profile_palette(n_levels), name = "Profile") +
    scale_fill_manual(values = profile_palette(n_levels), guide = "none") +
    labs(title = sprintf("Figure %d. Respondents in %s-%s factor space, %s",
                          fig_num, x_label, y_label, country_name),
         subtitle = "Regression factor scores from the 6-factor varimax solution; profiles overlaid",
         x = x_label, y = y_label,
         caption = "Diamonds = profile centroids. Factor scores are standardized to approximate unit variance.") +
    theme_thesis()
}

# Extract factor scores from fa_italy and fa_sweden
scores_it <- fa_italy$factor_scores
scores_se <- fa_sweden$factor_scores

# Fig 41: PA1 x PA2 Italy
cat("--- FIG 41: FA scatter PA1xPA2 Italy ---\n")
p41 <- plot_fa_scatter(scores_it, italy_clust, profile_order_italy, "Italy",
                       1, 2, "Factor 1", "Factor 2", 41, col_italy)
if (!is.null(p41)) save_fig(p41, "fig_41_fa_scatter_pa1_pa2_italy", w = 9, h = 6)

# Fig 42: PA1 x PA2 Sweden
cat("--- FIG 42: FA scatter PA1xPA2 Sweden ---\n")
p42 <- plot_fa_scatter(scores_se, sweden_clust, profile_order_sweden, "Sweden",
                       1, 2, "Factor 1", "Factor 2", 42, col_sweden)
if (!is.null(p42)) save_fig(p42, "fig_42_fa_scatter_pa1_pa2_sweden", w = 9, h = 6)

# Fig 43: PA3 x PA4 Italy
cat("--- FIG 43: FA scatter PA3xPA4 Italy ---\n")
p43 <- plot_fa_scatter(scores_it, italy_clust, profile_order_italy, "Italy",
                       3, 4, "Factor 3", "Factor 4", 43, col_italy)
if (!is.null(p43)) save_fig(p43, "fig_43_fa_scatter_pa3_pa4_italy", w = 9, h = 6)

# Fig 44: PA3 x PA4 Sweden
cat("--- FIG 44: FA scatter PA3xPA4 Sweden ---\n")
p44 <- plot_fa_scatter(scores_se, sweden_clust, profile_order_sweden, "Sweden",
                       3, 4, "Factor 3", "Factor 4", 44, col_sweden)
if (!is.null(p44)) save_fig(p44, "fig_44_fa_scatter_pa3_pa4_sweden", w = 9, h = 6)


# ##############################################################################
# FIG 45-46 — DENDROGRAM COMPARISON 3 LINKAGES
# ##############################################################################

plot_dendro_comparison <- function(X, country_col, country_name, fig_num, k_cut) {
  set.seed(42)
  idx <- sample(seq_len(nrow(X)), min(300, nrow(X)))
  X_sub <- X[idx, ]
  d <- dist(X_sub)

  methods <- c("ward.D2", "average", "complete")
  plots <- list()
  for (m in methods) {
    hc <- hclust(d, method = m)
    dd <- ggdendro::dendro_data(hc, type = "rectangle")
    cut_h <- sort(hc$height, decreasing = TRUE)[k_cut]
    plots[[m]] <- ggplot(dd$segments) +
      geom_segment(aes(x = x, y = y, xend = xend, yend = yend),
                   colour = country_col, linewidth = 0.25) +
      geom_hline(yintercept = cut_h, linetype = "dashed",
                 colour = col_accent, linewidth = 0.4) +
      labs(title = sprintf("%s linkage", tools::toTitleCase(m)),
           x = NULL, y = "Dissimilarity") +
      theme_thesis(base_size = 9) +
      theme(axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            panel.grid = element_blank())
  }

  combined <- plots[[1]] + plots[[2]] + plots[[3]] +
    plot_annotation(
      title = sprintf("Figure %d. Hierarchical clustering: linkage comparison, %s",
                       fig_num, country_name),
      subtitle = sprintf("300-obs subsample; dashed line marks k=%d cut across linkage methods", k_cut),
      caption = "Ward.D2 minimizes within-cluster variance; average and complete linkages shown as robustness checks.",
      theme = theme_thesis()
    )
  combined
}

cat("--- FIG 45: Dendrogram comparison Italy ---\n")
p45 <- plot_dendro_comparison(X_italy, col_italy, "Italy", 45, 5)
save_fig(p45, "fig_45_dendrogram_comparison_italy", w = 13, h = 5)

cat("--- FIG 46: Dendrogram comparison Sweden ---\n")
p46 <- plot_dendro_comparison(X_sweden, col_sweden, "Sweden", 46, 6)
save_fig(p46, "fig_46_dendrogram_comparison_sweden", w = 13, h = 5)


# ##############################################################################
# FIG 47-48 — BOXPLOTS KEY VARIABLES x PROFILE
# ##############################################################################

plot_boxplots_by_profile <- function(df, profile_order, country_name, fig_num) {
  # Nine key substantive variables. "age" is a demographic (not in var_labels)
  # so it is overridden manually; the rest are pulled from var_labels_scale so
  # wording matches the profile plots and factor-loading heatmaps.
  key_var_names <- c("age", "casp", "loneliness", "eurod", "mobility",
                     "iadl", "sn_size_w9", "fluency", "log_hnetw")
  key_vars <- setNames(relabel(key_var_names, style = "scale"), key_var_names)
  key_vars["age"] <- "Age (years)"
  # Unlabel haven_labelled if present
  for (v in names(key_vars)) {
    if (v %in% names(df)) df[[v]] <- as.numeric(as.vector(df[[v]]))
  }
  df$profile <- factor(as.character(df$profile), levels = profile_order)

  long <- df %>%
    select(profile, all_of(intersect(names(key_vars), names(df)))) %>%
    pivot_longer(-profile, names_to = "variable", values_to = "value") %>%
    mutate(variable = factor(variable,
                              levels = names(key_vars),
                              labels = key_vars[names(key_vars)]))

  n_profiles <- length(profile_order)
  ggplot(long, aes(x = profile, y = value, fill = profile)) +
    geom_boxplot(width = 0.55, outlier.size = 0.5, alpha = 0.85) +
    facet_wrap(~ variable, scales = "free_y", ncol = 3) +
    scale_fill_manual(values = profile_palette(n_profiles), guide = "none") +
    labs(title = sprintf("Figure %d. Boxplots of key variables by profile, %s",
                          fig_num, country_name),
         subtitle = "Distribution of nine substantive variables across the k-means profiles",
         x = NULL, y = NULL,
         caption = "Box shows median and IQR; whiskers extend to 1.5 x IQR; points beyond are individual outliers.") +
    theme_thesis() +
    theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 8))
}

cat("--- FIG 47: Boxplots by profile Italy ---\n")
p47 <- plot_boxplots_by_profile(italy_clust, profile_order_italy, "Italy", 47)
save_fig(p47, "fig_47_boxplots_by_profile_italy", w = 12, h = 8)

cat("--- FIG 48: Boxplots by profile Sweden ---\n")
p48 <- plot_boxplots_by_profile(sweden_clust, profile_order_sweden, "Sweden", 48)
save_fig(p48, "fig_48_boxplots_by_profile_sweden", w = 12, h = 8)


# ##############################################################################
# FIG 49 — SILHOUETTE BOXPLOT PER CLUSTER (IT + SE side-by-side)
# ##############################################################################

compute_silhouette_df <- function(X, clusters, profile_names, profile_order, country_name) {
  set.seed(42)
  idx <- sample(seq_len(nrow(X)), min(1500, nrow(X)))
  sil <- silhouette(clusters[idx], dist(X[idx, ]))
  data.frame(
    country   = country_name,
    profile   = factor(profile_names[clusters[idx]], levels = profile_order),
    sil_width = as.numeric(sil[, "sil_width"])
  )
}

km5_italy  <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_kmeans_k5.rds"))
km6_sweden <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_kmeans_k6.rds"))

cat("--- FIG 49: Silhouette boxplot per cluster IT + SE ---\n")

sil_df <- bind_rows(
  compute_silhouette_df(X_italy,  italy_clust$cluster_num,
                        km5_italy$profile_names,  profile_order_italy,  "Italy"),
  compute_silhouette_df(X_sweden, sweden_clust$cluster_num,
                        km6_sweden$profile_names, profile_order_sweden, "Sweden")
) %>%
  mutate(country = factor(country, levels = c("Italy", "Sweden")))

# Plot: per ogni paese, boxplot silhouette width by profile
p49 <- ggplot(sil_df, aes(x = profile, y = sil_width, fill = profile)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50", linewidth = 0.3) +
  geom_boxplot(width = 0.55, outlier.size = 0.5, alpha = 0.85) +
  facet_wrap(~ country, scales = "free_x", ncol = 2) +
  scale_fill_viridis_d(option = "D", end = 0.85, guide = "none") +
  labs(title = "Figure 49. Silhouette width by profile, Italy and Sweden",
       subtitle = "1,500-observation subsample per country",
       x = NULL, y = "Silhouette width",
       caption = "Higher silhouette width indicates tighter assignment to own cluster versus nearest neighbour cluster.") +
  theme_thesis() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 8))

save_fig(p49, "fig_49_silhouette_boxplot_by_cluster", w = 12, h = 5.5)


# ##############################################################################
# SUMMARY
# ##############################################################################

cat("\n============================================================\n")
cat("STEP 14 COMPLETATO.\n")
cat("  10 gap figures saved in:", fig_dir, "\n")
cat("  Figure totali Step 12+13+14: 49\n")
cat("============================================================\n")
