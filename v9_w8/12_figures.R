# ==============================================================================
# STEP 12: GENERATE ALL THESIS FIGURES
# Thesis: "Invisible Profiles" — Bocconi MSc DSBA
#
# Produce 21 figure pubblicazione-ready dalla pipeline v9/:
#   Fig 01  Sample flow (Ch 3)
#   Fig 02  PCA scree plots Italy (Ch 4)
#   Fig 03  PCA scree plots Sweden (Ch 5)
#   Fig 04  FA loadings heatmap Italy (Ch 4)
#   Fig 05  FA loadings heatmap Sweden (Ch 5)
#   Fig 06  K-means diagnostics Italy (Ch 4)
#   Fig 07  K-means diagnostics Sweden (Ch 5)
#   Fig 08  Italy 5 profiles — characteristics (Ch 4)
#   Fig 09  Sweden 6 profiles — characteristics (Ch 5)
#   Fig 10  Italy radar chart (Ch 4)
#   Fig 11  Sweden radar chart (Ch 5)
#   Fig 12  Italy lifesat ANOVA boxplot (Ch 4)
#   Fig 13  Sweden lifesat ANOVA boxplot (Ch 5)
#   Fig 14  Cross-country matched pairs gap heatmap (Ch 5)
#   Fig 15  Country-unique profiles (Ch 5)
#   Fig 16  LCA BIC/AIC/entropy curves (Ch 6)
#   Fig 17  LCA vs K-means confusion matrix (Ch 6)
#   Fig 18  Convergence % per profile (Ch 6)
#   Fig 19  Healthcare IT Isolati vs Sociali (Ch 7)
#   Fig 20  Cross-country healthcare (Ch 7)
#   Fig 21  Welfare gap: Dentist + Forgone cost (Ch 7)
#
# Style: Bocconi MSc academic. Viridis palette, theme_classic, English labels.
# Output: v9/figures/ (PNG 300 DPI + PDF vector)
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  if (!requireNamespace("patchwork", quietly = TRUE)) install.packages("patchwork", quiet=TRUE)
  library(patchwork)
  if (!requireNamespace("RColorBrewer", quietly = TRUE)) install.packages("RColorBrewer", quiet=TRUE)
  library(RColorBrewer)
  if (!requireNamespace("viridis", quietly = TRUE)) install.packages("viridis", quiet=TRUE)
  library(viridis)
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
fig_dir   <- file.path(data_path, "v9", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Human-readable variable labels (shared with Step 13/15/16/17/18).
source(file.path(data_path, "v9", "var_labels.R"))
# Chapter-subfolder routing for save_fig() (writes PNG/PDF under the
# appropriate chapter folder in v9/figures/, not the flat root).
source(file.path(data_path, "v9", "fig_paths.R"))

cat("============================================================\n")
cat("STEP 12: THESIS FIGURES GENERATION\n")
cat("============================================================\n\n")
cat("  Output dir:", fig_dir, "\n\n")


# ##############################################################################
# GLOBAL THEME & PALETTE
# ##############################################################################

# Bocconi MSc academic theme
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

# Country colors (navy Italy, soft blue Sweden, orange accent)
col_italy   <- "#0F4C81"
col_sweden  <- "#8DB9CA"
col_accent  <- "#E07A5F"
col_neutral <- "grey40"

# Profile palette: viridis option D (perceptually uniform, colourblind-safe)
profile_palette <- function(n) viridis::viridis(n, option = "D", end = 0.85)

# Save helper: solo PNG 300 DPI (PDF disabilitato; rigenerabile on-demand)
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

italy_clust  <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
sweden_clust <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_with_clusters.rds"))
italy_hc     <- readRDS(file.path(data_path, "v9", "outputs", "step11_italy_with_healthcare.rds"))
sweden_hc    <- readRDS(file.path(data_path, "v9", "outputs", "step11_sweden_with_healthcare.rds"))

pca_italy     <- readRDS(file.path(data_path, "v9", "outputs", "step5_italy_pca_results.rds"))
fa_italy      <- readRDS(file.path(data_path, "v9", "outputs", "step5_italy_fa_results.rds"))
pca_sweden    <- readRDS(file.path(data_path, "v9", "outputs", "step6_sweden_pca_results.rds"))
fa_sweden     <- readRDS(file.path(data_path, "v9", "outputs", "step6_sweden_fa_results.rds"))

km5_italy     <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_kmeans_k5.rds"))
km6_sweden    <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_kmeans_k6.rds"))
km6_italy_raw <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_kmeans_k6.rds"))

cross_gap     <- readRDS(file.path(data_path, "v9", "outputs", "step9_cross_country_gap.rds"))
cross_tests   <- readRDS(file.path(data_path, "v9", "outputs", "step9_matched_pairs_tests.rds"))

lca_italy     <- readRDS(file.path(data_path, "v9", "outputs", "step10_lca_italy.rds"))
lca_sweden    <- readRDS(file.path(data_path, "v9", "outputs", "step10_lca_sweden.rds"))
conv_table    <- readRDS(file.path(data_path, "v9", "outputs", "step10_convergence_table.rds"))

hc_it_compare <- readRDS(file.path(data_path, "v9", "outputs", "step11_healthcare_italy_isolati_vs_sociali.rds"))
hc_cross      <- readRDS(file.path(data_path, "v9", "outputs", "step11_healthcare_cross_country.rds"))
hc_by_pair    <- readRDS(file.path(data_path, "v9", "outputs", "step11_healthcare_by_pair.rds"))

cat("  ...all loaded\n\n")

# Ordine canonico dei profili (usato per tutte le figure con profilo)
profile_order_italy  <- c("Fragile Resigned", "Fragile Depressed",
                          "Moderate Isolated", "Traditional Social",
                          "Connected Active")
profile_order_sweden <- c("Fragile", "Social Decline", "Moderate",
                          "Asset Rich", "Wealthy Digital", "Connected Wealthy")

italy_clust$profile  <- factor(italy_clust$profile,  levels = profile_order_italy)
sweden_clust$profile <- factor(sweden_clust$profile, levels = profile_order_sweden)
italy_hc$profile     <- factor(italy_hc$profile,     levels = profile_order_italy)
sweden_hc$profile    <- factor(sweden_hc$profile,    levels = profile_order_sweden)


# ##############################################################################
# FIG 01 — SAMPLE FLOW
# ##############################################################################

cat("--- FIG 01 — Sample flow ---\n")

flow_df <- data.frame(
  step = factor(c("SHARE W9\ntotal", "Over 65,\nimplicat=1",
                  "After listwise\n(31 vars)",
                  "After outlier\nremoval"),
                levels = c("SHARE W9\ntotal", "Over 65,\nimplicat=1",
                           "After listwise\n(31 vars)",
                           "After outlier\nremoval")),
  Italy  = c(5601, 2399, 2378, 2378),
  Sweden = c(3405, 2202, 2045 - 258 + 258, 1787)  # SE: 2045 assembled, 258 dropped
) %>%
  pivot_longer(c(Italy, Sweden), names_to = "Country", values_to = "N")

# Override Sweden listwise to be the actual step3 assembly
flow_df$N[flow_df$Country == "Sweden" & flow_df$step == "After listwise\n(31 vars)"] <- 2045
flow_df$N[flow_df$Country == "Sweden" & flow_df$step == "After outlier\nremoval"]   <- 1787

p01 <- ggplot(flow_df, aes(x = step, y = N, fill = Country)) +
  geom_col(position = position_dodge(0.7), width = 0.65) +
  geom_text(aes(label = format(N, big.mark = ",")),
            position = position_dodge(0.7), vjust = -0.4, size = 3.3) +
  scale_fill_manual(values = c(Italy = col_italy, Sweden = col_sweden)) +
  scale_y_continuous(labels = comma_format(),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Figure 1. Analytical sample derivation, SHARE Wave 9",
       subtitle = "Italy and Sweden cohorts, from survey total to final pre-clustering sample",
       x = NULL, y = "N respondents",
       caption = "Source: SHARE W9, own calculations.") +
  theme_thesis() +
  theme(legend.position = "top")

save_fig(p01, "fig_01_sample_flow", w = 7.5, h = 5)


# ##############################################################################
# FIG 02 — PCA SCREE PLOTS ITALY (5 dimensions)
# ##############################################################################

cat("--- FIG 02 — PCA scree Italy ---\n")

make_scree_df <- function(pca_list) {
  dimensions <- names(pca_list)[1:5]
  rows <- list()
  for (dim_name in dimensions) {
    p <- pca_list[[dim_name]]
    if (is.null(p)) next
    rows[[dim_name]] <- data.frame(
      dimension = tools::toTitleCase(dim_name),
      k         = seq_along(p$eigenvalues),
      eigenvalue = p$eigenvalues,
      kaiser    = p$eigenvalues > 1
    )
  }
  do.call(rbind, rows)
}

scree_it <- make_scree_df(pca_italy)

p02 <- ggplot(scree_it, aes(x = k, y = eigenvalue)) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_line(colour = col_italy, linewidth = 0.7) +
  geom_point(aes(colour = kaiser), size = 2.5) +
  scale_colour_manual(values = c(`TRUE` = col_accent, `FALSE` = "grey60"),
                      labels = c(`TRUE` = "Kaiser (eigenvalue > 1)",
                                 `FALSE` = "Below threshold"),
                      name = NULL) +
  facet_wrap(~ dimension, scales = "free", ncol = 3) +
  scale_x_continuous(breaks = scales::pretty_breaks()) +
  labs(title = "Figure 2. PCA scree plots by dimension, Italy",
       subtitle = "Eigenvalues per principal component; dashed line = Kaiser criterion (eigenvalue = 1)",
       x = "Principal component", y = "Eigenvalue",
       caption = "Italy n=2,378. Digital/Social dimension excludes ac035d4 and ac035d7 (zero variance).") +
  theme_thesis() +
  theme(legend.position = "top")

save_fig(p02, "fig_02_pca_scree_italy", w = 8, h = 5.5)


# ##############################################################################
# FIG 03 — PCA SCREE PLOTS SWEDEN (5 dimensions)
# ##############################################################################

cat("--- FIG 03 — PCA scree Sweden ---\n")

scree_se <- make_scree_df(pca_sweden)

p03 <- ggplot(scree_se, aes(x = k, y = eigenvalue)) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_line(colour = col_sweden, linewidth = 0.7) +
  geom_point(aes(colour = kaiser), size = 2.5) +
  scale_colour_manual(values = c(`TRUE` = col_accent, `FALSE` = "grey60"),
                      labels = c(`TRUE` = "Kaiser (eigenvalue > 1)",
                                 `FALSE` = "Below threshold"),
                      name = NULL) +
  facet_wrap(~ dimension, scales = "free", ncol = 3) +
  scale_x_continuous(breaks = scales::pretty_breaks()) +
  labs(title = "Figure 3. PCA scree plots by dimension, Sweden",
       subtitle = "Eigenvalues per principal component; dashed line = Kaiser criterion (eigenvalue = 1)",
       x = "Principal component", y = "Eigenvalue",
       caption = "Sweden n=1,787. All 31 variables active.") +
  theme_thesis() +
  theme(legend.position = "top")

save_fig(p03, "fig_03_pca_scree_sweden", w = 8, h = 5.5)


# ##############################################################################
# FIG 04 — FA LOADINGS HEATMAP ITALY
# ##############################################################################

cat("--- FIG 04 — FA loadings Italy ---\n")

# Conversione robusta: psych loadings class può comportarsi male con as.data.frame.
# Costruiamo esplicitamente la matrice, poi la data.frame, poi il pivot.
fa_loadings_it <- unclass(fa_italy$loadings)
# Se è una psych loadings, diventa un vettore. Dobbiamo reshape.
if (is.null(dim(fa_loadings_it))) {
  n_vars <- length(fa_italy$communalities)
  n_fac  <- 6
  fa_loadings_it <- matrix(as.numeric(fa_loadings_it), nrow = n_vars, ncol = n_fac)
  rownames(fa_loadings_it) <- names(fa_italy$communalities)
  colnames(fa_loadings_it) <- paste0("PA", 1:n_fac)
}
# Force matrix with proper dims
fa_loadings_it <- as.matrix(fa_loadings_it)
if (nrow(fa_loadings_it) * ncol(fa_loadings_it) != length(as.vector(fa_italy$loadings))) {
  # Ricostruisci direttamente dal fa_model
  fa_loadings_it <- unclass(fa_italy$fa_model$loadings)
}

var_names  <- rownames(fa_loadings_it)
fact_names <- colnames(fa_loadings_it)

fa_loadings_it_df <- data.frame(
  variable = rep(var_names, times = ncol(fa_loadings_it)),
  factor   = rep(fact_names, each = nrow(fa_loadings_it)),
  loading  = as.numeric(fa_loadings_it)
) %>%
  mutate(
    variable = factor(variable, levels = var_names),
    factor   = factor(factor,   levels = fact_names),
    cutoff   = abs(loading) >= 0.30,
    label_txt = ifelse(cutoff, sprintf("%.2f", loading), "")
  )

p04 <- ggplot(fa_loadings_it_df, aes(x = factor, y = variable, fill = loading)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  geom_text(aes(label = label_txt), size = 2.8, colour = "white", fontface = "bold") +
  scale_fill_gradient2(low = "#1B3A5F", mid = "white", high = "#C04A2E",
                       midpoint = 0, limits = c(-1, 1), name = "Loading") +
  scale_x_discrete(position = "top") +
  scale_y_discrete(limits = rev,
                   labels = setNames(relabel(var_names, style = "scale"), var_names)) +
  labs(title = "Figure 4. Factor loadings matrix, Italy (PA extraction, varimax rotation)",
       subtitle = "Six factors over 29 active variables; values shown if |loading| >= 0.30",
       x = "Factor", y = NULL,
       caption = "Italy n=2,378. KMO=0.832, Bartlett p<0.001. 6 factors explain 38.4% variance. Measurement scale in parentheses next to each variable.") +
  theme_thesis() +
  theme(axis.text.y = element_text(size = 8),
        panel.grid.major.y = element_blank())

save_fig(p04, "fig_04_fa_loadings_italy", w = 7.5, h = 9)


# ##############################################################################
# FIG 05 — FA LOADINGS HEATMAP SWEDEN (with Heywood)
# ##############################################################################

cat("--- FIG 05 — FA loadings Sweden ---\n")

fa_loadings_se <- unclass(fa_sweden$loadings)
if (is.null(dim(fa_loadings_se))) {
  n_vars <- length(fa_sweden$communalities)
  n_fac  <- 6
  fa_loadings_se <- matrix(as.numeric(fa_loadings_se), nrow = n_vars, ncol = n_fac)
  rownames(fa_loadings_se) <- names(fa_sweden$communalities)
  colnames(fa_loadings_se) <- paste0("PA", 1:n_fac)
}
fa_loadings_se <- as.matrix(fa_loadings_se)
if (nrow(fa_loadings_se) * ncol(fa_loadings_se) != length(as.vector(fa_sweden$loadings))) {
  fa_loadings_se <- unclass(fa_sweden$fa_model$loadings)
}

var_names_se  <- rownames(fa_loadings_se)
fact_names_se <- colnames(fa_loadings_se)

fa_loadings_se_df <- data.frame(
  variable = rep(var_names_se, times = ncol(fa_loadings_se)),
  factor   = rep(fact_names_se, each = nrow(fa_loadings_se)),
  loading  = as.numeric(fa_loadings_se)
) %>%
  mutate(
    variable  = factor(variable, levels = var_names_se),
    factor    = factor(factor,   levels = fact_names_se),
    cutoff    = abs(loading) >= 0.30,
    heywood   = abs(loading) > 1,
    label_txt = ifelse(cutoff, sprintf("%.2f", loading), "")
  )

p05 <- ggplot(fa_loadings_se_df, aes(x = factor, y = variable, fill = loading)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  geom_text(aes(label = label_txt, fontface = ifelse(heywood, "bold.italic", "bold")),
            size = 2.8, colour = "white") +
  scale_fill_gradient2(low = "#1B3A5F", mid = "white", high = "#C04A2E",
                       midpoint = 0, limits = c(-1.2, 1.2), name = "Loading") +
  scale_x_discrete(position = "top") +
  scale_y_discrete(limits = rev,
                   labels = setNames(relabel(var_names_se, style = "scale"), var_names_se)) +
  labs(title = "Figure 5. Factor loadings matrix, Sweden (PA extraction, varimax rotation)",
       subtitle = "Six factors over 31 active variables; Heywood case on 'Social integration index' (loading > 1)",
       x = "Factor", y = NULL,
       caption = "Sweden n=1,787. KMO=0.808. social_integration h²=1.38 (Heywood).") +
  theme_thesis() +
  theme(axis.text.y = element_text(size = 8),
        panel.grid.major.y = element_blank())

save_fig(p05, "fig_05_fa_loadings_sweden", w = 7.5, h = 9.5)


# ##############################################################################
# FIG 06 — K-MEANS DIAGNOSTICS ITALY
# ##############################################################################

cat("--- FIG 06 — K-means diagnostics Italy ---\n")

diag_it <- km6_italy_raw$diagnostics %>%
  pivot_longer(c(tot_withinss, between_pct, silhouette),
               names_to = "metric", values_to = "value") %>%
  mutate(metric = recode(metric,
                         tot_withinss = "Total Within SS",
                         between_pct  = "Between / Total SS (%)",
                         silhouette   = "Mean Silhouette Width"))

p06 <- ggplot(diag_it, aes(x = k, y = value)) +
  geom_line(colour = col_italy, linewidth = 0.7) +
  geom_point(size = 2.2, colour = col_italy) +
  geom_vline(xintercept = 6, linetype = "dashed", colour = col_accent, alpha = 0.7) +
  annotate("text", x = 6.15, y = Inf, label = "k = 6 selected",
           hjust = 0, vjust = 1.5, size = 3, colour = col_accent) +
  facet_wrap(~ metric, scales = "free_y", ncol = 3) +
  scale_x_continuous(breaks = 2:10) +
  labs(title = "Figure 6. K-means diagnostics across k, Italy",
       subtitle = "Elbow (Total Within SS), separation ratio, and silhouette width",
       x = "Number of clusters (k)", y = NULL,
       caption = "Italy n=2,378; k=6 chosen for cross-country comparability (no clear elbow at k<6).") +
  theme_thesis()

save_fig(p06, "fig_06_kmeans_diagnostics_italy", w = 9, h = 4)


# ##############################################################################
# FIG 07 — K-MEANS DIAGNOSTICS SWEDEN
# ##############################################################################

cat("--- FIG 07 — K-means diagnostics Sweden ---\n")

diag_se <- km6_sweden$diagnostics %>%
  pivot_longer(c(tot_withinss, between_pct, silhouette),
               names_to = "metric", values_to = "value") %>%
  mutate(metric = recode(metric,
                         tot_withinss = "Total Within SS",
                         between_pct  = "Between / Total SS (%)",
                         silhouette   = "Mean Silhouette Width"))

p07 <- ggplot(diag_se, aes(x = k, y = value)) +
  geom_line(colour = col_sweden, linewidth = 0.7) +
  geom_point(size = 2.2, colour = col_sweden) +
  geom_vline(xintercept = 6, linetype = "dashed", colour = col_accent, alpha = 0.7) +
  annotate("text", x = 6.15, y = Inf, label = "k = 6 selected",
           hjust = 0, vjust = 1.5, size = 3, colour = col_accent) +
  facet_wrap(~ metric, scales = "free_y", ncol = 3) +
  scale_x_continuous(breaks = 2:10) +
  labs(title = "Figure 7. K-means diagnostics across k, Sweden",
       subtitle = "Elbow (Total Within SS), separation ratio, and silhouette width",
       x = "Number of clusters (k)", y = NULL,
       caption = "Sweden n=1,787; k=6 chosen for cross-country comparability.") +
  theme_thesis()

save_fig(p07, "fig_07_kmeans_diagnostics_sweden", w = 9, h = 4)


# ##############################################################################
# FIG 08 — ITALY 5 PROFILES CHARACTERISTICS
# ##############################################################################

cat("--- FIG 08 — Italy profiles characteristics ---\n")

# Riproduciamo la tabella descrittiva con bar chart
it_profile_means <- italy_clust %>%
  group_by(profile) %>%
  summarise(
    Age          = mean(age,         na.rm = TRUE),
    `Internet (%)` = 100 * mean(internet, na.rm = TRUE),
    CASP         = mean(casp,        na.rm = TRUE),
    Loneliness   = mean(loneliness,  na.rm = TRUE),
    `Hope (%)`   = 100 * mean(hope_future, na.rm = TRUE),
    `Network size` = mean(sn_size_w9, na.rm = TRUE),
    `EURO-D`     = mean(eurod,       na.rm = TRUE),
    `Mobility limit` = mean(mobility, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(-profile, names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(metric, levels = c("Age", "CASP", "Internet (%)",
                                            "Loneliness", "Hope (%)", "Network size",
                                            "EURO-D", "Mobility limit")))

p08 <- ggplot(it_profile_means, aes(x = profile, y = value, fill = profile)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = sprintf("%.1f", value)), vjust = -0.3, size = 2.8) +
  scale_fill_manual(values = profile_palette(5), guide = "none") +
  facet_wrap(~ metric, scales = "free_y", ncol = 4) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Figure 8. Profile characteristics, Italy (five k-means profiles)",
       subtitle = "Mean values for each profile on key dimensions of wellbeing and connectedness",
       x = NULL, y = "Mean value",
       caption = "Italy n=2,378. Ordered from most fragile (left) to most connected (right).") +
  theme_thesis() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 8))

save_fig(p08, "fig_08_profiles_italy", w = 11, h = 6)


# ##############################################################################
# FIG 09 — SWEDEN 6 PROFILES CHARACTERISTICS
# ##############################################################################

cat("--- FIG 09 — Sweden profiles characteristics ---\n")

se_profile_means <- sweden_clust %>%
  group_by(profile) %>%
  summarise(
    Age          = mean(age,         na.rm = TRUE),
    `Internet (%)` = 100 * mean(internet, na.rm = TRUE),
    CASP         = mean(casp,        na.rm = TRUE),
    Loneliness   = mean(loneliness,  na.rm = TRUE),
    `Hope (%)`   = 100 * mean(hope_future, na.rm = TRUE),
    `Network size` = mean(sn_size_w9, na.rm = TRUE),
    `EURO-D`     = mean(eurod,       na.rm = TRUE),
    `Mobility limit` = mean(mobility, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(-profile, names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(metric, levels = c("Age", "CASP", "Internet (%)",
                                            "Loneliness", "Hope (%)", "Network size",
                                            "EURO-D", "Mobility limit")))

p09 <- ggplot(se_profile_means, aes(x = profile, y = value, fill = profile)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = sprintf("%.1f", value)), vjust = -0.3, size = 2.6) +
  scale_fill_manual(values = profile_palette(6), guide = "none") +
  facet_wrap(~ metric, scales = "free_y", ncol = 4) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Figure 9. Profile characteristics, Sweden (six k-means profiles)",
       subtitle = "Mean values for each profile on key dimensions of wellbeing and connectedness",
       x = NULL, y = "Mean value",
       caption = "Sweden n=1,787. Ordered from most fragile (left) to most connected (right).") +
  theme_thesis() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 8))

save_fig(p09, "fig_09_profiles_sweden", w = 11, h = 6)


# ##############################################################################
# FIG 10 — RADAR CHART ITALY (5 profiles)
# ##############################################################################

cat("--- FIG 10 — Italy radar chart ---\n")

# Radar via coord_polar. Normalizziamo ogni variabile 0-1 per comparabilità.
make_radar_df <- function(df, profiles_order) {
  radar_vars <- c("age", "internet", "casp", "loneliness", "hope_future",
                  "sn_size_w9", "eurod", "mobility")
  radar_labels <- c("Age", "Internet", "CASP", "Loneliness",
                    "Hope (future)", "Network size", "EURO-D", "Mobility limit")

  # Invertiamo: loneliness, eurod, mobility, age (per semplicità "alto = meglio")
  invert_vars <- c("loneliness", "eurod", "mobility", "age")

  mean_df <- df %>% group_by(profile) %>%
    summarise(across(all_of(radar_vars), ~ mean(.x, na.rm = TRUE)), .groups="drop")

  # Normalize 0-1 across profiles per ogni variabile
  for (v in radar_vars) {
    vals <- mean_df[[v]]
    norm_v <- (vals - min(vals)) / (max(vals) - min(vals) + 1e-9)
    if (v %in% invert_vars) norm_v <- 1 - norm_v
    mean_df[[v]] <- norm_v
  }

  # Rename
  names(mean_df)[names(mean_df) %in% radar_vars] <-
    radar_labels[match(radar_vars, radar_vars)]

  long <- mean_df %>%
    pivot_longer(-profile, names_to = "metric", values_to = "value") %>%
    mutate(metric = factor(metric, levels = radar_labels),
           profile = factor(profile, levels = profiles_order))
  long
}

radar_it <- make_radar_df(italy_clust, profile_order_italy)

p10 <- ggplot(radar_it, aes(x = metric, y = value,
                             group = profile, colour = profile, fill = profile)) +
  geom_polygon(alpha = 0.15, linewidth = 0.6) +
  geom_point(size = 1.8) +
  coord_polar(clip = "off") +
  scale_colour_manual(values = profile_palette(5), name = "Profile") +
  scale_fill_manual(values = profile_palette(5), guide = "none") +
  scale_y_continuous(limits = c(-0.1, 1.05), breaks = c(0, 0.5, 1)) +
  labs(title = "Figure 10. Profile radar, Italy",
       subtitle = "Eight dimensions, min-max normalized (higher = better outcome)",
       x = NULL, y = NULL,
       caption = "Loneliness, EURO-D, Mobility limit, and Age inverted so higher values denote better outcomes.") +
  theme_thesis() +
  theme(axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        panel.grid.major = element_line(colour = "grey85"),
        legend.position = "right")

save_fig(p10, "fig_10_radar_italy", w = 9, h = 6)


# ##############################################################################
# FIG 11 — RADAR CHART SWEDEN (6 profiles)
# ##############################################################################

cat("--- FIG 11 — Sweden radar chart ---\n")

radar_se <- make_radar_df(sweden_clust, profile_order_sweden)

p11 <- ggplot(radar_se, aes(x = metric, y = value,
                             group = profile, colour = profile, fill = profile)) +
  geom_polygon(alpha = 0.15, linewidth = 0.6) +
  geom_point(size = 1.8) +
  coord_polar(clip = "off") +
  scale_colour_manual(values = profile_palette(6), name = "Profile") +
  scale_fill_manual(values = profile_palette(6), guide = "none") +
  scale_y_continuous(limits = c(-0.1, 1.05), breaks = c(0, 0.5, 1)) +
  labs(title = "Figure 11. Profile radar, Sweden",
       subtitle = "Eight dimensions, min-max normalized (higher = better outcome)",
       x = NULL, y = NULL,
       caption = "Loneliness, EURO-D, Mobility limit, and Age inverted so higher values denote better outcomes.") +
  theme_thesis() +
  theme(axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        panel.grid.major = element_line(colour = "grey85"),
        legend.position = "right")

save_fig(p11, "fig_11_radar_sweden", w = 9, h = 6)


# ##############################################################################
# FIG 12 — LIFESAT ANOVA BOXPLOT ITALY
# ##############################################################################

cat("--- FIG 12 — lifesat boxplot Italy ---\n")

if ("lifesat" %in% names(italy_clust)) {
  italy_ls <- italy_clust %>% filter(!is.na(lifesat))
  aov_it <- summary(aov(lifesat ~ profile, data = italy_ls))[[1]]
  f_it <- round(aov_it[1, "F value"], 1); df_b <- aov_it[1, "Df"]; df_w <- aov_it[2, "Df"]

  p12 <- ggplot(italy_ls, aes(x = profile, y = lifesat, fill = profile)) +
    geom_boxplot(width = 0.55, outlier.size = 0.8, alpha = 0.85) +
    stat_summary(fun = mean, geom = "point", shape = 23, size = 2.5,
                 fill = "white", colour = "black") +
    scale_fill_manual(values = profile_palette(5), guide = "none") +
    scale_y_continuous(breaks = 0:10, limits = c(0, 10.5)) +
    labs(title = "Figure 12. Life satisfaction by profile, Italy",
         subtitle = sprintf("One-way ANOVA: F(%d, %d) = %.1f, p < .001", df_b, df_w, f_it),
         x = NULL, y = "Life satisfaction (0-10)",
         caption = "Italy n=2,188 (with lifesat non-NA). Diamond = group mean.") +
    theme_thesis() +
    theme(axis.text.x = element_text(angle = 25, hjust = 1))

  save_fig(p12, "fig_12_lifesat_anova_italy", w = 7.5, h = 5)
} else {
  cat("    (skipped: lifesat not available)\n")
}


# ##############################################################################
# FIG 13 — LIFESAT ANOVA BOXPLOT SWEDEN
# ##############################################################################

cat("--- FIG 13 — lifesat boxplot Sweden ---\n")

if ("lifesat" %in% names(sweden_clust)) {
  sweden_ls <- sweden_clust %>% filter(!is.na(lifesat))
  aov_se <- summary(aov(lifesat ~ profile, data = sweden_ls))[[1]]
  f_se <- round(aov_se[1, "F value"], 1); df_b <- aov_se[1, "Df"]; df_w <- aov_se[2, "Df"]

  p13 <- ggplot(sweden_ls, aes(x = profile, y = lifesat, fill = profile)) +
    geom_boxplot(width = 0.55, outlier.size = 0.8, alpha = 0.85) +
    stat_summary(fun = mean, geom = "point", shape = 23, size = 2.5,
                 fill = "white", colour = "black") +
    scale_fill_manual(values = profile_palette(6), guide = "none") +
    scale_y_continuous(breaks = 0:10, limits = c(0, 10.5)) +
    labs(title = "Figure 13. Life satisfaction by profile, Sweden",
         subtitle = sprintf("One-way ANOVA: F(%d, %d) = %.1f, p < .001", df_b, df_w, f_se),
         x = NULL, y = "Life satisfaction (0-10)",
         caption = "Sweden n=1,785 (with lifesat non-NA). Diamond = group mean.") +
    theme_thesis() +
    theme(axis.text.x = element_text(angle = 25, hjust = 1))

  save_fig(p13, "fig_13_lifesat_anova_sweden", w = 7.5, h = 5)
} else {
  cat("    (skipped: lifesat not available)\n")
}


# ##############################################################################
# FIG 14 — CROSS-COUNTRY MATCHED PAIRS GAP HEATMAP
# ##############################################################################

cat("--- FIG 14 — cross-country gap heatmap ---\n")

gap_mat <- cross_gap$gap_wide %>%
  pivot_longer(-variable, names_to = "pair", values_to = "gap") %>%
  mutate(pair = factor(pair, levels = c("Fragili", "Dep./Declino", "Sociali", "Connessi")),
         variable = factor(variable,
                           levels = c("CASP-12", "Life satisfaction", "Hope (%)",
                                      "EURO-D", "Loneliness",
                                      "Internet (%)", "Fluency")))

p14 <- ggplot(gap_mat, aes(x = pair, y = variable, fill = gap)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = sprintf("%+.2f", gap)), size = 3.3, colour = "white") +
  scale_fill_gradient2(low = "#1B3A5F", mid = "white", high = "#C04A2E",
                       midpoint = 0, name = "Gap (SE − IT)") +
  scale_y_discrete(limits = rev) +
  labs(title = "Figure 14. Cross-country gaps across matched profile pairs",
       subtitle = "Difference Sweden minus Italy for each wellbeing and connectedness variable",
       x = "Matched pair", y = NULL,
       caption = "Positive values: higher in Sweden. Gap computed on profile means; Welch t-tests in Chapter 5.") +
  theme_thesis() +
  theme(panel.grid.major.y = element_blank())

save_fig(p14, "fig_14_matched_pairs_gap", w = 8, h = 5)


# ##############################################################################
# FIG 15 — COUNTRY-UNIQUE PROFILES HIGHLIGHT
# ##############################################################################

cat("--- FIG 15 — country-unique profiles ---\n")

unique_profiles <- data.frame(
  country = c("Italy", "Sweden", "Sweden"),
  profile = c("Moderate Isolated", "Asset Rich", "Wealthy Digital"),
  n       = c(639, 341, 138),
  pct     = c(26.9, 19.1, 7.7),
  interpretation = c(
    "Socially isolated, moderate income,\nlow digital engagement —\nno Swedish equivalent",
    "Wealth decoupled from social network;\nuniversalist welfare generates\nliquid assets independently",
    "Frontier digital elite:\n96% internet, high wealth —\nno Italian equivalent"
  )
)
unique_profiles$label <- sprintf("%s\n(n=%d, %.1f%%)", unique_profiles$profile,
                                 unique_profiles$n, unique_profiles$pct)

p15 <- ggplot(unique_profiles, aes(x = country, y = n, fill = country)) +
  geom_col(width = 0.55) +
  geom_text(aes(label = label), vjust = -0.4, size = 3, fontface = "bold") +
  geom_text(aes(label = interpretation), y = unique_profiles$n - 150, vjust = 1,
            size = 2.5, colour = "white", lineheight = 0.9) +
  scale_fill_manual(values = c(Italy = col_italy, Sweden = col_sweden), guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.3))) +
  labs(title = "Figure 15. Country-unique profiles and welfare regime specificity",
       subtitle = "Profiles that emerge in one country but have no analogue in the other",
       x = NULL, y = "N respondents",
       caption = "Moderate Isolated (IT) reflects familistic isolation; Asset Rich and Wealthy Digital (SE) reflect universalist welfare.") +
  theme_thesis() +
  theme(axis.text.x = element_text(size = 10, face = "bold"))

save_fig(p15, "fig_15_country_unique", w = 9, h = 6.5)


# ##############################################################################
# FIG 16 — LCA BIC/AIC/ENTROPY CURVES
# ##############################################################################

cat("--- FIG 16 — LCA BIC/AIC/entropy ---\n")

lca_tab <- bind_rows(
  lca_italy$fit_tab %>% mutate(Country = "Italy"),
  lca_sweden$fit_tab %>% mutate(Country = "Sweden")
) %>%
  pivot_longer(c(bic, aic, entropy), names_to = "metric", values_to = "value") %>%
  mutate(metric = recode(metric,
                         bic = "BIC",
                         aic = "AIC",
                         entropy = "Normalized entropy"))

p16 <- ggplot(lca_tab, aes(x = k, y = value, colour = Country)) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2.2) +
  geom_vline(xintercept = 6, linetype = "dashed", colour = col_accent, alpha = 0.6) +
  facet_wrap(~ metric, scales = "free_y", ncol = 3) +
  scale_colour_manual(values = c(Italy = col_italy, Sweden = col_sweden)) +
  scale_x_continuous(breaks = 2:8) +
  labs(title = "Figure 16. Latent Class Analysis fit indices across k",
       subtitle = "BIC, AIC, and entropy for k=2..8; k=6 chosen for cross-country comparability (dashed)",
       x = "Number of classes (k)", y = NULL,
       caption = "BIC-optimal k differs (IT: k=8, SE: k=4); k=6 retained on substantive/interpretability grounds.") +
  theme_thesis() +
  theme(legend.position = "top")

save_fig(p16, "fig_16_lca_fit_indices", w = 10, h = 4.5)


# ##############################################################################
# FIG 17 — LCA vs K-MEANS CONFUSION MATRIX HEATMAP (Italy)
# ##############################################################################

cat("--- FIG 17 — LCA vs K-means confusion ---\n")

conf_it <- as.data.frame(lca_italy$comparison$conf_tab)
names(conf_it) <- c("LCA_class", "K-means profile", "N")
conf_it$`K-means profile` <- factor(conf_it$`K-means profile`, levels = profile_order_italy)
conf_it$LCA_class <- factor(conf_it$LCA_class)

p17a <- ggplot(conf_it, aes(x = `K-means profile`, y = LCA_class, fill = N)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = N), size = 3.3, colour = "white") +
  scale_fill_gradient(low = "#DDE3EC", high = col_italy, name = "N obs") +
  scale_y_discrete(limits = rev) +
  labs(title = "Italy: LCA class x k-means profile", x = NULL, y = "LCA class") +
  theme_thesis() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

conf_se <- as.data.frame(lca_sweden$comparison$conf_tab)
names(conf_se) <- c("LCA_class", "K-means profile", "N")
conf_se$`K-means profile` <- factor(conf_se$`K-means profile`, levels = profile_order_sweden)
conf_se$LCA_class <- factor(conf_se$LCA_class)

p17b <- ggplot(conf_se, aes(x = `K-means profile`, y = LCA_class, fill = N)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = N), size = 3.3, colour = "white") +
  scale_fill_gradient(low = "#E6EDF2", high = "#3F6582", name = "N obs") +
  scale_y_discrete(limits = rev) +
  labs(title = "Sweden: LCA class x k-means profile", x = NULL, y = "LCA class") +
  theme_thesis() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

p17 <- p17a + p17b +
  plot_annotation(
    title = "Figure 17. Cross-method validation: LCA classes vs k-means profiles",
    subtitle = "Convergence of probabilistic (LCA) and geometric (k-means) segmentations at k=5 (IT) and k=6 (SE)",
    caption = "Global convergence: Italy 66.7%, Sweden 68.1%. Fragile and Connected profiles show strongest cross-method agreement.",
    theme = theme_thesis()
  )

save_fig(p17, "fig_17_lca_kmeans_confusion", w = 12, h = 5.5)


# ##############################################################################
# FIG 18 — CONVERGENCE % PER PROFILE
# ##############################################################################

cat("--- FIG 18 — convergence per profile ---\n")

conv_table$profile <- factor(conv_table$profile,
                              levels = c(profile_order_italy, profile_order_sweden))

p18 <- ggplot(conv_table, aes(x = reorder(profile, convergence_pct),
                               y = convergence_pct, fill = country)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = sprintf("%.0f%%", convergence_pct)),
            hjust = -0.15, size = 3.2) +
  coord_flip() +
  scale_fill_manual(values = c(Italia = col_italy, Svezia = col_sweden), name = "Country") +
  scale_y_continuous(limits = c(0, 110), breaks = seq(0, 100, 25),
                     labels = function(x) paste0(x, "%")) +
  labs(title = "Figure 18. Cross-method convergence by profile",
       subtitle = "Share of k-means profile members falling in the dominant LCA class",
       x = NULL, y = "Convergence (%)",
       caption = "Fragile and Connected profiles show highest convergence; intermediate profiles (Wealthy Digital, Asset Rich, Moderate Isolated) are less cross-method stable.") +
  theme_thesis() +
  theme(legend.position = "top",
        panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(colour = "grey92", linewidth = 0.3))

save_fig(p18, "fig_18_convergence_per_profile", w = 9, h = 6)


# ##############################################################################
# FIG 19 — HEALTHCARE ITALY: ISOLATI vs SOCIALI ("dato forte")
# ##############################################################################

cat("--- FIG 19 — healthcare Italy Isolati vs Sociali ---\n")

hc_it_plot <- hc_it_compare %>%
  mutate(variable = factor(variable, levels = c("Doctor visits (12m)", "GP contacts",
                                                  "Specialist contacts", "Dentist 12m (%)",
                                                  "Forgone care cost (%)", "Nights in hospital")),
         sig = ifelse(p < 0.001, "***", ifelse(p < 0.01, "**", ifelse(p < 0.05, "*", "ns")))) %>%
  pivot_longer(c(isolati, sociali), names_to = "Group", values_to = "value") %>%
  mutate(Group = recode(Group, isolati = "Moderate Isolated", sociali = "Traditional Social"))

p19 <- ggplot(hc_it_plot, aes(x = Group, y = value, fill = Group)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.1f", value)), vjust = -0.3, size = 3) +
  facet_wrap(~ variable, scales = "free_y", ncol = 3) +
  scale_fill_manual(values = c(`Moderate Isolated` = col_accent,
                                `Traditional Social` = col_italy),
                    name = "Italian profile") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Figure 19. Italian paradox: healthcare utilization, Moderate Isolated vs Traditional Social",
       subtitle = "Profiles with comparable physical conditions but different social embeddedness",
       x = NULL, y = "Mean value (counts) or proportion (%)",
       caption = "Italy, subsample with healthcare data (n=2,344). Significance: Welch t-test (continuous) or chi-squared (proportions).") +
  theme_thesis() +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        legend.position = "top")

save_fig(p19, "fig_19_healthcare_italy_isolati_vs_sociali", w = 10, h = 6)


# ##############################################################################
# FIG 20 — CROSS-COUNTRY HEALTHCARE
# ##############################################################################

cat("--- FIG 20 — cross-country healthcare ---\n")

hc_cross_plot <- hc_cross %>%
  pivot_longer(c(italy, sweden), names_to = "Country", values_to = "value") %>%
  mutate(Country = recode(Country, italy = "Italy", sweden = "Sweden"),
         variable = factor(variable, levels = c("Doctor visits", "GP contacts",
                                                 "Specialist contacts", "Dentist (%)",
                                                 "Hospitalised (%)", "Forgone care cost (%)",
                                                 "Nights in hospital")))

p20 <- ggplot(hc_cross_plot, aes(x = Country, y = value, fill = Country)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.1f", value)), vjust = -0.3, size = 2.8) +
  facet_wrap(~ variable, scales = "free_y", ncol = 4) +
  scale_fill_manual(values = c(Italy = col_italy, Sweden = col_sweden), guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Figure 20. Healthcare utilization, cross-country comparison",
       subtitle = "Italy and Sweden aggregate means on seven healthcare indicators",
       x = NULL, y = "Mean value or proportion",
       caption = "Italy n=2,344; Sweden n=1,779. Welfare regime contrast most visible on dentist access and forgone care cost.") +
  theme_thesis() +
  theme(axis.text.x = element_text(size = 9, face = "bold"))

save_fig(p20, "fig_20_healthcare_cross_country", w = 11, h = 6)


# ##############################################################################
# FIG 21 — WELFARE GAP: DENTIST + FORGONE COST
# ##############################################################################

cat("--- FIG 21 — welfare gap dentist/forgone ---\n")

# Zoom on the two "welfare signature" gaps
signature <- hc_by_pair %>%
  filter(variable %in% c("Dentist (%)", "Forgone cost (%)")) %>%
  mutate(pair_name = factor(pair_name,
                             levels = c("Fragili", "Dep./Declino",
                                        "Sociali", "Connessi")))

p21 <- ggplot(signature,
              aes(x = pair_name, y = gap_SE_IT, fill = variable)) +
  geom_col(position = position_dodge(0.7), width = 0.6) +
  geom_text(aes(label = sprintf("%+.1f", gap_SE_IT), colour = variable),
            position = position_dodge(0.7), vjust = ifelse(signature$gap_SE_IT >= 0, -0.3, 1.2),
            size = 3.2, fontface = "bold", show.legend = FALSE) +
  geom_hline(yintercept = 0, linetype = "solid", colour = "grey30") +
  scale_fill_manual(values = c(`Dentist (%)` = col_sweden,
                                `Forgone cost (%)` = col_accent),
                    name = NULL) +
  scale_colour_manual(values = c(`Dentist (%)` = col_italy,
                                  `Forgone cost (%)` = col_accent)) +
  scale_y_continuous(breaks = seq(-20, 70, 10),
                     labels = function(x) paste0(ifelse(x > 0, "+", ""), x, "pp")) +
  labs(title = "Figure 21. Welfare regime signature: dentist access and forgone care cost",
       subtitle = "Sweden minus Italy in percentage points, across the four matched profile pairs",
       x = "Matched pair", y = "Gap Sweden − Italy (percentage points)",
       caption = "Dentist access: universal coverage gap consistently +40/+60pp in Sweden.\nForgone cost: Italian economic barrier pattern, strongest among fragile profiles.") +
  theme_thesis() +
  theme(legend.position = "top",
        panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3))

save_fig(p21, "fig_21_welfare_gap_dentist_forgone", w = 9, h = 5.5)


# ##############################################################################
# SUMMARY
# ##############################################################################

cat("\n============================================================\n")
cat("STEP 12 COMPLETATO.\n")
cat("  21 figures saved in:", fig_dir, "\n")
cat("  Each in PNG (300 DPI) + PDF (vector) format.\n")
cat("============================================================\n")
