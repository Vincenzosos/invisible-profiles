# ==============================================================================
# STEP 13: ADDITIONAL THESIS FIGURES (COURSE 20570 CANON)
# Thesis: "Invisible Profiles" — Bocconi MSc DSBA
#
# Aggiunge 18 figure oltre a quelle di Step 12 per coprire il canon del corso
# Trentini (PCA+FA+Cluster hands-on). Mantiene stile identico a Step 12
# (theme_thesis, viridis palette, PNG 300 DPI + PDF).
#
#   Fig 22  Cluster quality indexes k=2..10 — Italy       (Ch 4 / App)
#   Fig 23  Cluster quality indexes k=2..10 — Sweden      (Ch 5 / App)
#   Fig 24  Hierarchical dendrogram (ward.D2) — Italy     (App)
#   Fig 25  Hierarchical dendrogram (ward.D2) — Sweden    (App)
#   Fig 26  Method comparison (kmeans vs ward) — Italy    (Ch 6)
#   Fig 27  Method comparison — Sweden                    (Ch 6)
#   Fig 28  Silhouette plot per-individual — Italy        (Ch 4)
#   Fig 29  Silhouette plot per-individual — Sweden       (Ch 5)
#   Fig 30  Scatter PC1×PC2 colored by profile — Italy    (Ch 4)
#   Fig 31  Scatter PC1×PC2 colored by profile — Sweden   (Ch 5)
#   Fig 32  Parallel analysis plot — Italy                (Ch 4)
#   Fig 33  Parallel analysis plot — Sweden               (Ch 5)
#   Fig 34  Communalities heatmap (IT + SE side-by-side)  (Ch 4-5 / App)
#   Fig 35  FA fit comparison 4-8 factors (IT + SE)       (Ch 6)
#   Fig 36  Demographics stacked bar: gender × profile IT (Ch 4)
#   Fig 37  Demographics stacked bar: age band × profile IT (Ch 4)
#   Fig 38  Demographics stacked bar: gender × profile SE (Ch 5)
#   Fig 39  Demographics stacked bar: age band × profile SE (Ch 5)
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(cluster)     # silhouette, dist
  library(patchwork)
  library(viridis)
  library(RColorBrewer)
  if (!requireNamespace("fpc", quietly = TRUE)) install.packages("fpc", quiet = TRUE)
  library(fpc)         # cluster.stats for PseudoF, Dunn, etc.
  if (!requireNamespace("ggdendro", quietly = TRUE)) install.packages("ggdendro", quiet = TRUE)
  library(ggdendro)    # ggplot2-based dendrograms
  if (!requireNamespace("psych", quietly = TRUE)) install.packages("psych", quiet = TRUE)
  library(psych)       # fa, fa.parallel
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
fig_dir   <- file.path(data_path, "v9", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Human-readable variable labels (shared with Step 12/14/15/16/17/18).
source(file.path(data_path, "v9", "var_labels.R"))
# Chapter-subfolder routing for save_fig().
source(file.path(data_path, "v9", "fig_paths.R"))

cat("============================================================\n")
cat("STEP 13: ADDITIONAL FIGURES (COURSE CANON)\n")
cat("============================================================\n\n")


# ##############################################################################
# GLOBAL THEME & PALETTE (identico a Step 12)
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

col_italy   <- "#0F4C81"
col_sweden  <- "#8DB9CA"
col_accent  <- "#E07A5F"
col_neutral <- "grey40"
profile_palette <- function(n) viridis::viridis(n, option = "D", end = 0.85)

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

cat("--- Loading v9/ pipeline outputs ---\n")

italy_std   <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_std.rds"))
sweden_std  <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_std.rds"))
italy_clust <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
sweden_clust<- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_with_clusters.rds"))

pca_italy     <- readRDS(file.path(data_path, "v9", "outputs", "step5_italy_pca_results.rds"))
fa_italy      <- readRDS(file.path(data_path, "v9", "outputs", "step5_italy_fa_results.rds"))
pca_sweden    <- readRDS(file.path(data_path, "v9", "outputs", "step6_sweden_pca_results.rds"))
fa_sweden     <- readRDS(file.path(data_path, "v9", "outputs", "step6_sweden_fa_results.rds"))

km5_italy     <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_kmeans_k5.rds"))
km6_sweden    <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_kmeans_k6.rds"))

cat("  ...all loaded\n\n")

# Variabili attive
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
# FIG 22 & 23 — CLUSTER QUALITY INDEXES k=2..10
# ##############################################################################

compute_quality_indexes <- function(X, k_range, seed = 42) {
  # Subsample for speed (cluster.stats with full matrix is slow)
  set.seed(seed)
  n <- nrow(X)
  idx <- if (n > 1000) sample(seq_len(n), 1000) else seq_len(n)
  X_sub <- X[idx, ]
  d_sub <- dist(X_sub)

  results <- list()
  for (k in k_range) {
    set.seed(seed)
    km <- kmeans(X, centers = k, nstart = 50, iter.max = 200)
    # Cluster stats on subsample (faster)
    km_sub <- kmeans(X_sub, centers = k, nstart = 20, iter.max = 200)
    stats <- suppressWarnings(cluster.stats(d_sub, km_sub$cluster))
    # R² = between / total SS (from full kmeans)
    r2 <- 1 - km$tot.withinss / km$totss
    results[[length(results) + 1]] <- data.frame(
      k        = k,
      R2       = r2,
      Silhouette = stats$avg.silwidth,
      PseudoF  = stats$ch,
      Dunn     = stats$dunn,
      Ptbiserial = stats$pearsongamma,
      DB       = stats$wb.ratio   # surrogate for Davies-Bouldin (lower = better)
    )
  }
  do.call(rbind, results)
}

cat("--- FIG 22: Cluster quality indexes Italy ---\n")
qi_italy  <- compute_quality_indexes(X_italy,  2:10)
cat("--- FIG 23: Cluster quality indexes Sweden ---\n")
qi_sweden <- compute_quality_indexes(X_sweden, 2:10)

plot_quality_indexes <- function(qi, country_col, country_name, k_chosen, fig_num) {
  df <- qi %>%
    pivot_longer(-k, names_to = "metric", values_to = "value") %>%
    mutate(metric = factor(metric,
             levels = c("R2", "Silhouette", "PseudoF", "Dunn", "Ptbiserial", "DB"),
             labels = c("R\u00b2 (higher=better)", "Silhouette (higher=better)",
                        "Pseudo-F / CH (higher=better)", "Dunn index (higher=better)",
                        "Pearson-gamma (higher=better)", "wb.ratio (lower=better)")))

  ggplot(df, aes(x = k, y = value)) +
    geom_line(colour = country_col, linewidth = 0.7) +
    geom_point(size = 2.2, colour = country_col) +
    geom_vline(xintercept = k_chosen, linetype = "dashed", colour = col_accent, alpha = 0.6) +
    facet_wrap(~ metric, scales = "free_y", ncol = 3) +
    scale_x_continuous(breaks = 2:10) +
    labs(title = sprintf("Figure %d. Cluster quality indexes, %s", fig_num, country_name),
         subtitle = sprintf("Six internal validity criteria across k; dashed line marks k=%d selected", k_chosen),
         x = "Number of clusters (k)", y = NULL,
         caption = "Computed on a 1,000-observation subsample for computational tractability; R\u00b2 computed on the full sample.") +
    theme_thesis()
}

p22 <- plot_quality_indexes(qi_italy,  col_italy,  "Italy",  6, 22)
save_fig(p22, "fig_22_cluster_quality_italy", w = 11, h = 6.5)

p23 <- plot_quality_indexes(qi_sweden, col_sweden, "Sweden", 6, 23)
save_fig(p23, "fig_23_cluster_quality_sweden", w = 11, h = 6.5)


# ##############################################################################
# FIG 24 & 25 — HIERARCHICAL DENDROGRAM (ward.D2)
# ##############################################################################

plot_dendrogram <- function(X, country_col, country_name, k_cut, fig_num) {
  # Subsample for readability (full dendrogram on 2000+ points unreadable)
  set.seed(42)
  idx <- sample(seq_len(nrow(X)), min(500, nrow(X)))
  X_sub <- X[idx, ]
  d <- dist(X_sub)
  hc <- hclust(d, method = "ward.D2")

  dendro_data <- ggdendro::dendro_data(hc, type = "rectangle")
  # Color branches by cluster cut at k_cut
  clusters <- cutree(hc, k = k_cut)

  ggplot(dendro_data$segments) +
    geom_segment(aes(x = x, y = y, xend = xend, yend = yend), colour = country_col, linewidth = 0.3) +
    geom_hline(yintercept = sort(hc$height, decreasing = TRUE)[k_cut], linetype = "dashed",
               colour = col_accent, linewidth = 0.5) +
    annotate("text", x = max(dendro_data$segments$x) * 0.6,
             y = sort(hc$height, decreasing = TRUE)[k_cut] * 1.05,
             label = sprintf("cut at k=%d", k_cut), colour = col_accent, size = 3.2) +
    labs(title = sprintf("Figure %d. Hierarchical dendrogram (ward.D2), %s", fig_num, country_name),
         subtitle = sprintf("500-observation subsample; dashed line marks the k=%d cut", k_cut),
         x = NULL, y = "Dissimilarity (Euclidean, Ward linkage)",
         caption = "Hierarchical clustering reported as robustness check against k-means; see Chapter 6 for cross-method convergence.") +
    theme_thesis() +
    theme(axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          panel.grid = element_blank())
}

cat("--- FIG 24: Dendrogram Italy ---\n")
p24 <- plot_dendrogram(X_italy, col_italy, "Italy", 5, 24)
save_fig(p24, "fig_24_dendrogram_italy", w = 10, h = 5)

cat("--- FIG 25: Dendrogram Sweden ---\n")
p25 <- plot_dendrogram(X_sweden, col_sweden, "Sweden", 6, 25)
save_fig(p25, "fig_25_dendrogram_sweden", w = 10, h = 5)


# ##############################################################################
# FIG 26 & 27 — METHOD COMPARISON: KMEANS vs HIERARCHICAL (ward.D2)
# ##############################################################################

method_comparison <- function(X, km_clusters, k, country_name, country_col, fig_num) {
  # Hierarchical clustering at same k
  set.seed(42)
  d  <- dist(X)
  hc <- hclust(d, method = "ward.D2")
  hc_clusters <- cutree(hc, k = k)

  # Crosstab
  tab <- table(kmeans = km_clusters, ward = hc_clusters)
  df <- as.data.frame(tab)
  names(df) <- c("kmeans", "ward", "N")

  # Convergence metric: Adjusted Rand Index (optional)
  # Simple: % of obs in modal agreement
  total_mode_agreement <- 0
  for (k_cl in unique(km_clusters)) {
    mask <- km_clusters == k_cl
    if (sum(mask) == 0) next
    tab_row <- table(hc_clusters[mask])
    total_mode_agreement <- total_mode_agreement + max(tab_row)
  }
  pct_agreement <- 100 * total_mode_agreement / length(km_clusters)

  ggplot(df, aes(x = factor(kmeans), y = factor(ward), fill = N)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    geom_text(aes(label = N), size = 3.2, colour = "white") +
    scale_fill_gradient(low = paste0(country_col, "30"), high = country_col, name = "N obs") +
    scale_y_discrete(limits = rev) +
    labs(title = sprintf("Figure %d. K-means vs Ward hierarchical (k=%d), %s", fig_num, k, country_name),
         subtitle = sprintf("Modal-class convergence: %.1f%%", pct_agreement),
         x = "K-means cluster", y = "Ward cluster",
         caption = "Agreement measured as share of k-means members falling in the modal Ward cluster. Serves as robustness check on partition stability.") +
    theme_thesis() +
    theme(panel.grid = element_blank())
}

cat("--- FIG 26: Method comparison Italy ---\n")
p26 <- method_comparison(X_italy,  italy_clust$cluster_num,  5, "Italy",  col_italy,  26)
save_fig(p26, "fig_26_method_comparison_italy", w = 8, h = 6)

cat("--- FIG 27: Method comparison Sweden ---\n")
p27 <- method_comparison(X_sweden, sweden_clust$cluster_num, 6, "Sweden", col_sweden, 27)
save_fig(p27, "fig_27_method_comparison_sweden", w = 8, h = 6)


# ##############################################################################
# FIG 28 & 29 — SILHOUETTE PLOT PER-INDIVIDUAL
# ##############################################################################

plot_silhouette_per_ind <- function(X, clusters, profile_names, profile_order, country_name, fig_num) {
  # Compute silhouette on subsample (full is slow)
  set.seed(42)
  idx <- sample(seq_len(nrow(X)), min(1500, nrow(X)))
  sil <- silhouette(clusters[idx], dist(X[idx, ]))

  df <- data.frame(
    cluster_num = as.integer(sil[, "cluster"]),
    neighbor    = as.integer(sil[, "neighbor"]),
    sil_width   = as.numeric(sil[, "sil_width"]),
    profile     = factor(profile_names[clusters[idx]], levels = profile_order)
  ) %>%
    arrange(profile, sil_width) %>%
    mutate(x = row_number())

  mean_sil <- round(mean(df$sil_width), 3)

  ggplot(df, aes(x = x, y = sil_width, fill = profile)) +
    geom_col(width = 1) +
    geom_hline(yintercept = mean_sil, linetype = "dashed", colour = "grey30") +
    annotate("text", x = nrow(df) * 0.05, y = mean_sil + 0.05,
             label = sprintf("mean = %.3f", mean_sil),
             colour = "grey20", size = 3.2, hjust = 0) +
    scale_fill_manual(values = profile_palette(length(levels(df$profile))), name = "Profile") +
    labs(title = sprintf("Figure %d. Silhouette width per respondent, %s", fig_num, country_name),
         subtitle = "Respondents ordered by profile and then by silhouette width",
         x = NULL, y = "Silhouette width",
         caption = "1,500-observation subsample. Positive widths indicate assignments closer to own cluster than to neighbours.") +
    theme_thesis() +
    theme(axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          panel.grid.major.x = element_blank(),
          legend.position = "right")
}

cat("--- FIG 28: Silhouette per-ind Italy ---\n")
p28 <- plot_silhouette_per_ind(X_italy,  italy_clust$cluster_num,
                                km5_italy$profile_names, profile_order_italy,
                                "Italy", 28)
save_fig(p28, "fig_28_silhouette_per_ind_italy", w = 10, h = 5.5)

cat("--- FIG 29: Silhouette per-ind Sweden ---\n")
p29 <- plot_silhouette_per_ind(X_sweden, sweden_clust$cluster_num,
                                km6_sweden$profile_names, profile_order_sweden,
                                "Sweden", 29)
save_fig(p29, "fig_29_silhouette_per_ind_sweden", w = 10, h = 5.5)


# ##############################################################################
# FIG 30 & 31 — SCATTER PC1 × PC2 COLORED BY PROFILE
# ##############################################################################

plot_pc_scatter <- function(X, pca_result_list, clusters, profile_names, profile_order,
                             country_name, fig_num, block = "health") {
  # Usa il primo blocco PCA (Health) che dà PC1-PC2 nella stessa scala
  # In realtà per visualizzazione migliore: PCA globale su tutte le 29/31 vars
  # Ricalcoliamo PCA globale su X
  pca_global <- prcomp(X, center = FALSE, scale. = FALSE)  # già std
  pc_scores <- pca_global$x[, 1:2]

  var_expl <- 100 * (pca_global$sdev[1:2]^2) / sum(pca_global$sdev^2)

  df <- data.frame(
    PC1 = pc_scores[, 1],
    PC2 = pc_scores[, 2],
    profile = factor(profile_names[clusters], levels = profile_order)
  )

  # Cluster centroids in PC space
  cent <- df %>% group_by(profile) %>%
    summarise(PC1 = mean(PC1), PC2 = mean(PC2), .groups = "drop")

  ggplot(df, aes(x = PC1, y = PC2, colour = profile)) +
    geom_point(alpha = 0.35, size = 1.2) +
    geom_point(data = cent, aes(x = PC1, y = PC2, fill = profile),
               size = 4, shape = 23, colour = "black", stroke = 0.5) +
    scale_colour_manual(values = profile_palette(length(levels(df$profile))), name = "Profile") +
    scale_fill_manual(values = profile_palette(length(levels(df$profile))), guide = "none") +
    labs(title = sprintf("Figure %d. Respondents in first-two PC space, %s",
                          fig_num, country_name),
         subtitle = "Global PCA on the analytical variable set; profiles overlaid",
         x = sprintf("PC1 (%.1f%% var)", var_expl[1]),
         y = sprintf("PC2 (%.1f%% var)", var_expl[2]),
         caption = "Diamonds = profile centroids. Separation along PC1 reflects the dominant frailty-versus-connectedness gradient.") +
    theme_thesis()
}

cat("--- FIG 30: PC scatter Italy ---\n")
p30 <- plot_pc_scatter(X_italy, pca_italy, italy_clust$cluster_num,
                        km5_italy$profile_names, profile_order_italy, "Italy", 30)
save_fig(p30, "fig_30_pc_scatter_italy", w = 9, h = 6)

cat("--- FIG 31: PC scatter Sweden ---\n")
p31 <- plot_pc_scatter(X_sweden, pca_sweden, sweden_clust$cluster_num,
                        km6_sweden$profile_names, profile_order_sweden, "Sweden", 31)
save_fig(p31, "fig_31_pc_scatter_sweden", w = 9, h = 6)


# ##############################################################################
# FIG 32 & 33 — PARALLEL ANALYSIS PLOT
# ##############################################################################

plot_parallel_analysis <- function(X, country_col, country_name, fig_num, n_iter = 50) {
  # Compute real eigenvalues
  R <- cor(X)
  eig_actual <- eigen(R)$values

  # Compute simulated eigenvalues (parallel analysis)
  set.seed(42)
  n_vars <- ncol(X)
  n_obs  <- nrow(X)

  sim_eig <- matrix(NA, nrow = n_iter, ncol = n_vars)
  for (i in 1:n_iter) {
    X_rand <- matrix(rnorm(n_obs * n_vars), nrow = n_obs, ncol = n_vars)
    R_rand <- cor(X_rand)
    sim_eig[i, ] <- eigen(R_rand)$values
  }
  mean_sim <- colMeans(sim_eig)
  p95_sim  <- apply(sim_eig, 2, quantile, 0.95)

  df <- data.frame(
    factor_num = 1:n_vars,
    actual = eig_actual,
    mean_random = mean_sim,
    p95_random = p95_sim
  )

  # Suggested n factors: where actual > p95 random
  n_suggested <- sum(df$actual > df$p95_random)

  df_long <- df %>%
    pivot_longer(c(actual, mean_random, p95_random),
                 names_to = "series", values_to = "eigenvalue") %>%
    mutate(series = factor(series,
             levels = c("actual", "mean_random", "p95_random"),
             labels = c("Observed (actual data)", "Random data (mean)", "Random data (95%)")))

  ggplot(df_long, aes(x = factor_num, y = eigenvalue, colour = series, linetype = series)) +
    geom_line(linewidth = 0.7) +
    geom_point(data = subset(df_long, series == "Observed (actual data)"), size = 2) +
    geom_hline(yintercept = 1, linetype = "dotted", colour = "grey50") +
    geom_vline(xintercept = n_suggested, linetype = "dashed", colour = col_accent, alpha = 0.6) +
    annotate("text", x = n_suggested + 0.3, y = max(df$actual) * 0.85,
             label = sprintf("parallel suggests: %d", n_suggested),
             colour = col_accent, size = 3.2, hjust = 0) +
    scale_colour_manual(values = c(country_col, "grey60", "grey40"), name = NULL) +
    scale_linetype_manual(values = c("solid", "dashed", "dotted"), name = NULL) +
    scale_x_continuous(breaks = function(l) pretty(l, n = 10)) +
    labs(title = sprintf("Figure %d. Parallel analysis, %s", fig_num, country_name),
         subtitle = "Observed eigenvalues against mean and 95% quantile of eigenvalues from random matrices",
         x = "Factor number", y = "Eigenvalue",
         caption = sprintf("Parallel analysis with %d random datasets. Suggested factors: %d (crosses the 95%% random threshold).",
                           n_iter, n_suggested)) +
    theme_thesis() +
    theme(legend.position = "top")
}

cat("--- FIG 32: Parallel analysis Italy ---\n")
p32 <- plot_parallel_analysis(X_italy, col_italy, "Italy", 32)
save_fig(p32, "fig_32_parallel_analysis_italy", w = 9, h = 5.5)

cat("--- FIG 33: Parallel analysis Sweden ---\n")
p33 <- plot_parallel_analysis(X_sweden, col_sweden, "Sweden", 33)
save_fig(p33, "fig_33_parallel_analysis_sweden", w = 9, h = 5.5)


# ##############################################################################
# FIG 34 — COMMUNALITIES HEATMAP IT + SE SIDE-BY-SIDE
# ##############################################################################

cat("--- FIG 34: Communalities heatmap IT + SE ---\n")

# Estrai communalities h2 per ciascun paese
h2_italy  <- fa_italy$communalities
h2_sweden <- fa_sweden$communalities

# Allinea su unione delle variabili attive
all_vars <- union(names(h2_italy), names(h2_sweden))
h2_df <- data.frame(
  variable = all_vars,
  Italy    = h2_italy[all_vars],
  Sweden   = h2_sweden[all_vars]
) %>%
  pivot_longer(c(Italy, Sweden), names_to = "country", values_to = "h2") %>%
  mutate(
    country = factor(country, levels = c("Italy", "Sweden")),
    variable = factor(variable, levels = rev(all_vars)),
    label_txt = ifelse(is.na(h2), "", sprintf("%.2f", h2))
  )

p34 <- ggplot(h2_df, aes(x = country, y = variable, fill = h2)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = label_txt), size = 2.8, colour = "white") +
  scale_fill_gradient(low = "#E6EDF2", high = "#0F4C81", name = "h\u00b2", limits = c(0, 1.4),
                      na.value = "grey85") +
  scale_y_discrete(labels = setNames(relabel(all_vars, style = "scale"), all_vars)) +
  labs(title = "Figure 34. Communalities per variable, Italy and Sweden",
       subtitle = "Extracted from the 6-factor principal-axis solution with varimax rotation",
       x = NULL, y = NULL,
       caption = "Communalities (h\u00b2) summarize shared variance captured by the factor solution. Values > 1 denote Heywood cases ('Social integration index' in Sweden, h\u00b2 = 1.38). Measurement scales shown in parentheses next to each variable.") +
  theme_thesis() +
  theme(panel.grid = element_blank(),
        axis.text.y = element_text(size = 8),
        axis.text.x = element_text(size = 10, face = "bold"))

save_fig(p34, "fig_34_communalities_heatmap", w = 6, h = 9)


# ##############################################################################
# FIG 35 — FIT COMPARISON 4-8 FACTORS (IT + SE)
# ##############################################################################

cat("--- FIG 35: FA fit comparison 4-8 factors ---\n")

fit_comparison <- function(X, country_name) {
  results <- list()
  for (nf in 4:8) {
    fit <- tryCatch(
      suppressWarnings(psych::fa(X, nfactors = nf, rotate = "varimax",
                                  fm = "pa", warnings = FALSE)),
      error = function(e) NULL
    )
    if (is.null(fit)) next
    results[[length(results)+1]] <- data.frame(
      country = country_name, nfactors = nf,
      RMSR = fit$rms, TLI = fit$TLI,
      RMSEA = fit$RMSEA[1], BIC = fit$BIC
    )
  }
  do.call(rbind, results)
}

fc_italy  <- fit_comparison(X_italy,  "Italy")
fc_sweden <- fit_comparison(X_sweden, "Sweden")
fc <- rbind(fc_italy, fc_sweden) %>%
  pivot_longer(c(RMSR, TLI, RMSEA, BIC), names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(metric, levels = c("RMSR", "TLI", "RMSEA", "BIC")))

p35 <- ggplot(fc, aes(x = nfactors, y = value, colour = country, group = country)) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2.2) +
  geom_vline(xintercept = 6, linetype = "dashed", colour = col_accent, alpha = 0.6) +
  facet_wrap(~ metric, scales = "free_y", ncol = 4) +
  scale_colour_manual(values = c(Italy = col_italy, Sweden = col_sweden)) +
  scale_x_continuous(breaks = 4:8) +
  labs(title = "Figure 35. Factor-analysis fit indices across number of factors",
       subtitle = "Four fit indices for k = 4 to 8 factors; dashed line marks the k=6 design choice",
       x = "Number of factors", y = NULL,
       caption = "The six-factor solution is conservative relative to BIC optima (k=7 IT, k=4 SE) but is retained for cross-country comparability.") +
  theme_thesis() +
  theme(legend.position = "top")

save_fig(p35, "fig_35_fa_fit_comparison", w = 11, h = 4.5)


# ##############################################################################
# FIG 36-37 — DEMOGRAPHICS ITALY (gender × profile, age band × profile)
# ##############################################################################

demographics_stacked <- function(df, country_name, country_col, var_col, var_label, fig_num,
                                  profile_order) {
  # Unlabel haven_labelled vectors (age, gender da SHARE raw via haven)
  if ("age" %in% names(df))    df$age    <- as.numeric(as.vector(df$age))
  if ("gender" %in% names(df)) df$gender <- as.numeric(as.vector(df$gender))

  # Binna age in 3 bands if var is age
  if (var_col == "age_band") {
    df$group <- cut(df$age, breaks = c(-Inf, 74, 84, Inf),
                    labels = c("65-74", "75-84", "85+"))
  } else if (var_col == "gender_label") {
    df$group <- factor(ifelse(df$gender == 2, "Female", "Male"), levels = c("Female", "Male"))
  }

  df$profile <- factor(as.character(df$profile), levels = profile_order)
  df <- df[!is.na(df$group), ]

  # Costruisci tabella via base R (più robusta con haven_labelled residui)
  tab <- as.data.frame(table(group = df$group, profile = df$profile),
                       stringsAsFactors = FALSE, responseName = "n")
  tab <- tab %>%
    group_by(group) %>%
    mutate(pct = 100 * n / sum(n)) %>%
    ungroup() %>%
    mutate(profile = factor(profile, levels = profile_order))

  ggplot(tab, aes(x = group, y = pct, fill = profile)) +
    geom_col(position = "stack", width = 0.65) +
    geom_text(aes(label = ifelse(pct >= 4, sprintf("%.0f%%", pct), "")),
              position = position_stack(vjust = 0.5),
              size = 2.8, colour = "white") +
    scale_fill_manual(values = profile_palette(length(profile_order)), name = "Profile") +
    scale_y_continuous(labels = function(x) paste0(x, "%"), expand = c(0, 0)) +
    labs(title = sprintf("Figure %d. Profile composition by %s, %s", fig_num, var_label, country_name),
         subtitle = sprintf("Percentage of each %s group falling in each profile (100%% stacked)", var_label),
         x = tools::toTitleCase(var_label), y = NULL,
         caption = "Percentages within each column sum to 100%.") +
    theme_thesis() +
    theme(panel.grid.major.y = element_blank(),
          legend.position = "right")
}

cat("--- FIG 36: Gender × profile Italy ---\n")
p36 <- demographics_stacked(italy_clust, "Italy", col_italy, "gender_label",
                             "gender", 36, profile_order_italy)
save_fig(p36, "fig_36_demographics_gender_italy", w = 8, h = 5.5)

cat("--- FIG 37: Age × profile Italy ---\n")
p37 <- demographics_stacked(italy_clust, "Italy", col_italy, "age_band",
                             "age band", 37, profile_order_italy)
save_fig(p37, "fig_37_demographics_age_italy", w = 8, h = 5.5)

cat("--- FIG 38: Gender × profile Sweden ---\n")
p38 <- demographics_stacked(sweden_clust, "Sweden", col_sweden, "gender_label",
                             "gender", 38, profile_order_sweden)
save_fig(p38, "fig_38_demographics_gender_sweden", w = 8, h = 5.5)

cat("--- FIG 39: Age × profile Sweden ---\n")
p39 <- demographics_stacked(sweden_clust, "Sweden", col_sweden, "age_band",
                             "age band", 39, profile_order_sweden)
save_fig(p39, "fig_39_demographics_age_sweden", w = 8, h = 5.5)


# ##############################################################################
# SUMMARY
# ##############################################################################

cat("\n============================================================\n")
cat("STEP 13 COMPLETATO.\n")
cat("  18 additional figures saved in:", fig_dir, "\n")
cat("  Figure totali (Step 12 + 13): 39\n")
cat("============================================================\n")
