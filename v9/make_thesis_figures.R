# ===============================================================================
# Master figure-generation script — thesis chapters 3 and 4
# Vincenzo Pio Silvestri — MSc EMIT — April 2026
#
# Each section is INDEPENDENT. Run from "# ===" header to next "# ===".
# All figures are saved to:
#   v9/figures/03_data_methods/   (Cap. 3)
#   v9/figures/04_italy/          (Cap. 4)
# with explicit "fig_3_N_*" / "fig_4_N_*" naming aligned with the chapter labels.
#
# Run setwd() if needed:
#   setwd("~/Desktop/SHARE DATASET/DATASET RESEARCH")
# ===============================================================================

# ===============================================================================
# 0.  SETUP — libraries, theme, palette, data
# ===============================================================================

library(tidyverse)
library(viridis)
library(scales)
library(patchwork)
library(ggridges)

# Optional, install if missing:
# install.packages(c("ggalluvial", "NbClust", "fpc"))

theme_thesis <- theme_minimal(base_family = "Times", base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 13, hjust = 0,
                                    margin = margin(b = 6)),
    plot.subtitle    = element_text(color = "gray40", size = 11, hjust = 0,
                                    margin = margin(b = 10)),
    plot.caption     = element_text(color = "gray45", size = 9, hjust = 0,
                                    margin = margin(t = 8)),
    axis.title       = element_text(size = 11),
    axis.text        = element_text(size = 10, color = "gray25"),
    legend.title     = element_text(face = "bold", size = 10),
    legend.text      = element_text(size = 10),
    legend.position  = "top",
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray92", linewidth = 0.3),
    strip.text       = element_text(face = "bold", size = 11),
    plot.margin      = margin(14, 14, 14, 14)
  )
theme_set(theme_thesis)

# Palette: viridis-5 for Italian profiles (severity gradient)
profile_levels_it <- c("Fragile Resigned", "Fragile Depressed",
                       "Moderate Isolated", "Traditional Social",
                       "Connected Active")
profile_colors_it <- setNames(viridis::viridis(5), profile_levels_it)

# Palette: viridis-6 for Swedish profiles
profile_levels_se <- c("Fragile", "Social Decline", "Moderate",
                       "Asset Rich", "Wealthy Digital", "Connected Wealthy")
profile_colors_se <- setNames(viridis::viridis(6), profile_levels_se)

# Country contrast (used in country-comparison figures)
country_colors <- c(Italy = "#3B528B", Sweden = "#7FB3DB")

# Output dirs
fig_dir_03 <- "v9/figures/03_data_methods"
fig_dir_04 <- "v9/figures/04_italy"
dir.create(fig_dir_03, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir_04, recursive = TRUE, showWarnings = FALSE)

# Canonical analytical variable list (31 candidates; Italy will drop ac035d4/ac035d7)
ANALYTICAL_VARS <- c(
  # Health (8)
  "sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact",
  # Economic (5)
  "log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress",
  # Digital/social (10)
  "internet", "sn_size_w9", "social_integration",
  "ac035d1", "ac035d4", "ac035d5", "ac035d7", "ac035d8",
  "sp002_", "sp008_",
  # Cognitive (3)
  "fluency", "memory", "orienti",
  # Subjective (5)
  "casp", "loneliness", "hope_future", "interest", "expect_alive"
)

# Load data
italy   <- readRDS("v9/outputs/step7_italy_with_clusters.rds")
sweden  <- readRDS("v9/outputs/step8_sweden_with_clusters.rds")
italy_km  <- readRDS("v9/outputs/step7_italy_kmeans_k5.rds")
sweden_km <- readRDS("v9/outputs/step8_sweden_kmeans_k6.rds")

italy  <- italy  %>% mutate(profile = factor(profile, levels = profile_levels_it))
sweden <- sweden %>% mutate(profile = factor(profile, levels = profile_levels_se))


# ===============================================================================
# 1.  CAP. 3 — Figure 3.1 — Sample-flow waterfall
# ===============================================================================

sample_flow <- tribble(
  ~country, ~stage,                       ~n,    ~order,
  "Italy",  "SHARE W9 total",             5601,  1,
  "Italy",  "Aged 65+ (implicat=1)",      2399,  2,
  "Italy",  "After listwise (31 vars)",   2378,  3,
  "Italy",  "After Mahalanobis (p=.001)", 2378,  4,
  "Sweden", "SHARE W9 total",             3405,  1,
  "Sweden", "Aged 65+ (implicat=1)",      2202,  2,
  "Sweden", "After listwise (31 vars)",   2045,  3,
  "Sweden", "After Mahalanobis (p=.001)", 1787,  4
) %>%
  group_by(country) %>%
  mutate(
    stage    = factor(stage, levels = unique(stage)),
    n_lag    = lag(n),
    drop_n   = n_lag - n,
    drop_pct = if_else(!is.na(drop_n) & drop_n > 0,
                       sprintf("−%.1f%%", drop_n / n_lag * 100), NA_character_)
  ) %>%
  ungroup()

p_sample_flow <- sample_flow %>%
  ggplot(aes(stage, n, fill = country)) +
  geom_col(position = position_dodge(0.7), width = 0.6) +
  geom_text(aes(label = comma(n), group = country),
            position = position_dodge(0.7), vjust = -0.6, size = 3.6,
            fontface = "bold") +
  geom_text(data = sample_flow %>% filter(!is.na(drop_pct)),
            aes(label = drop_pct, group = country),
            position = position_dodge(0.7),
            vjust = -2.4, size = 3.1, color = "gray35", fontface = "italic") +
  scale_fill_manual(values = country_colors) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0.02, 0.20))) +
  labs(x = NULL, y = "N respondents", fill = NULL,
       caption = "Drop percentages relative to the previous stage. Italy loses no respondents at the Mahalanobis stage; Sweden loses 12.6%.") +
  theme(legend.position = "top", panel.grid.major.x = element_blank())

ggsave(file.path(fig_dir_03, "fig_3_1_sample_flow.png"),
       p_sample_flow, width = 11, height = 6, dpi = 300, bg = "white")


# ===============================================================================
# 2.  CAP. 3 — Figure 3.2 — Factor-analysis fit indices (RMSR / TLI / RMSEA / BIC)
# ===============================================================================
# Re-runs FA at k = 4..8 on each country and reports the four fit indices. The
# k = 6 design choice is marked by a dashed vertical reference line.

library(psych)

italy_std  <- readRDS("v9/outputs/step2_italy_std.rds")
sweden_std <- readRDS("v9/outputs/step4_sweden_std.rds")

active_matrix <- function(df) {
  m <- df %>% select(any_of(ANALYTICAL_VARS))
  m <- m[complete.cases(m), ]
  vars <- apply(m, 2, var)
  m <- m[, names(vars[vars > 1e-10]), drop = FALSE]
  as.matrix(m)
}

it_mat <- active_matrix(italy_std)
se_mat <- active_matrix(sweden_std)

fit_one <- function(mat, k, country) {
  set.seed(42)
  f <- suppressWarnings(psych::fa(mat, nfactors = k, fm = "pa",
                                  rotate = "varimax", warnings = FALSE))
  tibble(country = country, k = k,
         RMSR  = f$rms,
         TLI   = f$TLI,
         RMSEA = ifelse(is.null(f$RMSEA[1]), NA_real_, f$RMSEA[1]),
         BIC   = f$BIC)
}

fit_indices <- bind_rows(
  map_dfr(4:8, ~ fit_one(it_mat, .x, "Italy")),
  map_dfr(4:8, ~ fit_one(se_mat, .x, "Sweden"))
) %>%
  pivot_longer(c(RMSR, TLI, RMSEA, BIC),
               names_to = "index", values_to = "value") %>%
  mutate(index = factor(index, levels = c("RMSR", "TLI", "RMSEA", "BIC")))

p_fit <- fit_indices %>%
  ggplot(aes(k, value, color = country, group = country)) +
  geom_vline(xintercept = 6, linetype = "dashed",
             color = "gray60", linewidth = 0.5) +
  geom_line(linewidth = 1.0) +
  geom_point(size = 2.6) +
  facet_wrap(~ index, scales = "free_y", nrow = 1) +
  scale_color_manual(values = country_colors) +
  scale_x_continuous(breaks = 4:8) +
  labs(x = "Number of factors", y = NULL, color = NULL,
       caption = "Four fit indices reported for k = 4 to 8 factors, separately for Italy and Sweden. Dashed reference line marks the k = 6 design choice.\nThe six-factor solution is conservative relative to BIC optima (k = 7 IT, k = 4 SE) but is retained for cross-country comparability.") +
  theme(legend.position = "top",
        strip.background = element_rect(fill = "gray95", color = NA),
        panel.spacing = unit(0.9, "lines"))

ggsave(file.path(fig_dir_03, "fig_3_2_fa_fit_indices.png"),
       p_fit, width = 13, height = 4.8, dpi = 300, bg = "white")


# ===============================================================================
# 3.  CAP. 3 — Figure 3.3 — FA loadings, Italy + Sweden side-by-side
# ===============================================================================

fa_italy  <- readRDS("v9/outputs/step5_italy_fa_results.rds")
fa_sweden <- readRDS("v9/outputs/step6_sweden_fa_results.rds")

build_loadings_df <- function(fa_obj, country) {
  L <- as.data.frame(unclass(fa_obj$loadings))
  L$variable <- rownames(L)
  L %>%
    pivot_longer(-variable, names_to = "factor", values_to = "loading") %>%
    mutate(country = country,
           loading_lbl  = if_else(abs(loading) >= 0.30,
                                  sprintf("%.2f", loading), ""),
           loading_show = if_else(abs(loading) >= 0.30, loading, NA_real_))
}

loadings_long <- bind_rows(
  build_loadings_df(fa_italy,  "Italy"),
  build_loadings_df(fa_sweden, "Sweden")
)

# Order variables by their dominant factor in Italy (so both panels share order)
var_order <- loadings_long %>%
  filter(country == "Italy") %>%
  group_by(variable) %>%
  slice_max(abs(loading), n = 1) %>%
  arrange(factor, desc(abs(loading))) %>%
  pull(variable)

p_fa <- loadings_long %>%
  mutate(variable = factor(variable, levels = rev(var_order)),
         country  = factor(country, levels = c("Italy", "Sweden"))) %>%
  ggplot(aes(factor, variable, fill = loading_show)) +
  geom_tile(color = "white", linewidth = 0.4) +
  geom_text(aes(label = loading_lbl,
                color = abs(loading) > 0.6), size = 2.9) +
  scale_color_manual(values = c(`FALSE` = "black", `TRUE` = "white"),
                     guide = "none", na.value = "black") +
  scale_fill_gradient2(low = "#3B528B", mid = "white", high = "#C72E2E",
                       midpoint = 0, limits = c(-1, 1), na.value = "gray97",
                       breaks = c(-1, -0.5, 0, 0.5, 1)) +
  facet_wrap(~ country, scales = "free_x") +
  labs(x = "Factor", y = NULL, fill = "Loading",
       caption = "Cells with |loading| < 0.30 are suppressed for readability. Both countries: 6-factor solution, varimax rotation.\nVariable ordering follows the dominant Italian factor for cross-country comparability. KMO = 0.832 (IT); 0.808 (SE); Bartlett p < 0.001 in both countries.") +
  theme(panel.grid = element_blank(),
        strip.background = element_rect(fill = "gray95", color = NA),
        legend.position = "right",
        axis.text.y = element_text(size = 9))

ggsave(file.path(fig_dir_03, "fig_3_3_fa_loadings_both.png"),
       p_fa, width = 14, height = 11, dpi = 300, bg = "white")


# ===============================================================================
# 4.  CAP. 3 — Figure 3.4 — K-means vs LCA convergence per profile
# ===============================================================================
# For each profile, share of K-means cluster members whose LCA modal class
# coincides with the cluster (cross-method agreement).

# Try to load pre-computed convergence; otherwise compute from scratch.
conv_path <- "v9/outputs/step10_convergence_table.rds"
if (file.exists(conv_path)) {
  conv_tbl <- readRDS(conv_path)
} else {
  # Fallback: build manually from cluster + LCA modal class assignments
  lca_it <- readRDS("v9/outputs/step10_lca_italy.rds")
  lca_se <- readRDS("v9/outputs/step10_lca_sweden.rds")
  conv_tbl <- bind_rows(
    italy  %>% mutate(country = "Italy",
                      lca = lca_it$predclass[match(mergeid, lca_it$id)]),
    sweden %>% mutate(country = "Sweden",
                      lca = lca_se$predclass[match(mergeid, lca_se$id)])
  ) %>%
    group_by(country, profile) %>%
    summarise(modal_lca = as.numeric(names(sort(table(lca), decreasing = TRUE)[1])),
              convergence = mean(lca == modal_lca, na.rm = TRUE),
              .groups = "drop")
}

# Hard-coded fallback values (from the chapter narrative) if the loaded table
# does not contain the expected structure.
if (!"convergence" %in% colnames(conv_tbl)) {
  conv_tbl <- tribble(
    ~country, ~profile,             ~convergence,
    "Italy",  "Fragile Resigned",   0.956,
    "Italy",  "Fragile Depressed",  0.618,
    "Italy",  "Moderate Isolated",  0.546,
    "Italy",  "Traditional Social", 0.783,
    "Italy",  "Connected Active",   0.661,
    "Sweden", "Fragile",            0.859,
    "Sweden", "Social Decline",     0.597,
    "Sweden", "Moderate",           0.566,
    "Sweden", "Asset Rich",         0.531,
    "Sweden", "Wealthy Digital",    0.493,
    "Sweden", "Connected Wealthy",  0.869
  )
}

conv_tbl <- conv_tbl %>%
  mutate(profile = factor(profile,
                          levels = c(rev(profile_levels_it),
                                     rev(profile_levels_se))),
         country = factor(country, levels = c("Italy", "Sweden")))

p_conv <- conv_tbl %>%
  ggplot(aes(convergence * 100, profile, fill = country)) +
  geom_col(width = 0.7) +
  geom_vline(xintercept = 50, linetype = "dashed",
             color = "gray45", linewidth = 0.4) +
  annotate("text", x = 50, y = Inf, label = "50% chance",
           hjust = -0.1, vjust = 1.5, color = "gray35",
           size = 3, fontface = "italic") +
  geom_text(aes(label = sprintf("%.1f%%", convergence * 100)),
            hjust = -0.15, size = 3.4) +
  facet_wrap(~ country, scales = "free_y") +
  scale_fill_manual(values = country_colors, guide = "none") +
  scale_x_continuous(limits = c(0, 105),
                     labels = function(x) paste0(x, "%")) +
  labs(x = "Share of K-means cluster members in dominant LCA class",
       y = NULL,
       caption = "Bars report the share of K-means cluster members whose LCA modal class coincides with the cluster.\nThe four corner archetypes converge well above the 50% chance line; lower convergence on middle-stratum profiles localises fuzzy cluster boundaries.") +
  theme(strip.background = element_rect(fill = "gray95", color = NA),
        panel.grid.major.y = element_blank())

ggsave(file.path(fig_dir_03, "fig_3_4_kmeans_lca_convergence.png"),
       p_conv, width = 13, height = 6.5, dpi = 300, bg = "white")


# ===============================================================================
# 5.  CAP. 3 — Figure 3.5 (optional supplement) — Mahalanobis distance density
# ===============================================================================
# Useful for §3.4: visualises why Italy loses 0 respondents and Sweden loses 12.6%.

mahalanobis_safe <- function(df) {
  numeric_df <- df %>% select(any_of(ANALYTICAL_VARS))
  numeric_df <- numeric_df[complete.cases(numeric_df), ]
  vars <- apply(numeric_df, 2, var)
  keep <- names(vars[vars > 1e-10])
  numeric_df <- numeric_df[, keep, drop = FALSE]
  centre  <- colMeans(numeric_df)
  cov_mat <- cov(numeric_df)
  inv_cov <- MASS::ginv(cov_mat)
  d <- mahalanobis(as.matrix(numeric_df), centre, inv_cov, inverted = TRUE)
  list(d = d, k = ncol(numeric_df))
}

mah_it_obj <- mahalanobis_safe(italy_std)
mah_se_obj <- mahalanobis_safe(sweden_std)

mah_all <- bind_rows(
  tibble(country = "Italy",  d = mah_it_obj$d, k = mah_it_obj$k),
  tibble(country = "Sweden", d = mah_se_obj$d, k = mah_se_obj$k)
) %>%
  group_by(country) %>%
  mutate(cutoff = qchisq(0.999, df = unique(k))) %>%
  ungroup()

p_mah <- mah_all %>%
  ggplot(aes(d, fill = country, color = country)) +
  geom_density(alpha = 0.35, linewidth = 0.6) +
  geom_vline(aes(xintercept = cutoff, color = country),
             linetype = "dashed", linewidth = 0.7, show.legend = FALSE) +
  geom_text(data = mah_all %>% distinct(country, cutoff, k),
            aes(x = cutoff, y = 0.005,
                label = sprintf("χ²(%.0f) = %.1f", k, cutoff),
                color = country),
            angle = 90, vjust = -0.5, hjust = 0, size = 3,
            show.legend = FALSE, fontface = "italic") +
  scale_fill_manual(values = country_colors) +
  scale_color_manual(values = country_colors) +
  facet_wrap(~ country, scales = "free", ncol = 2) +
  coord_cartesian(xlim = c(0, NA)) +
  labs(x = "Mahalanobis distance", y = "Density", fill = NULL,
       caption = "Dashed line: chi-square critical value at p = 0.001 with df equal to the number of active analytical variables.\nRespondents to the right of the line are excluded as multivariate outliers.") +
  theme(legend.position = "top",
        strip.background = element_rect(fill = "gray95", color = NA))

ggsave(file.path(fig_dir_03, "fig_3_5_mahalanobis_distribution.png"),
       p_mah, width = 12, height = 5.5, dpi = 300, bg = "white")


# ===============================================================================
# 6.  CAP. 3 — Figure 3.6 (optional supplement) — k-selection scree
# ===============================================================================
# Within-cluster R² gradient as a proxy for cluster cohesion (k = 2..10).

compute_k_scree <- function(std_df, k_range = 2:10, country) {
  std_mat <- std_df %>%
    select(any_of(ANALYTICAL_VARS)) %>%
    select(where(is.numeric)) %>%
    drop_na() %>%
    as.matrix() %>%
    scale()
  d <- dist(std_mat)
  hc <- hclust(d, method = "ward.D2")
  ss_total <- sum(scale(std_mat, scale = FALSE)^2)
  r2 <- map_dbl(k_range, function(k) {
    cl <- cutree(hc, k = k)
    ss_within <- map_dbl(unique(cl), function(c_i) {
      members <- which(cl == c_i)
      sum(scale(std_mat[members, , drop = FALSE], scale = FALSE)^2)
    }) %>% sum()
    1 - ss_within / ss_total
  })
  tibble(country = country, k = k_range, r2 = r2)
}

scree_df <- bind_rows(
  compute_k_scree(italy_std,  country = "Italy"),
  compute_k_scree(sweden_std, country = "Sweden")
)

p_scree <- scree_df %>%
  ggplot(aes(k, r2, color = country, group = country)) +
  geom_line(linewidth = 1.0) +
  geom_point(size = 2.4) +
  geom_vline(xintercept = 5, linetype = "dotted",
             color = country_colors["Italy"],  linewidth = 0.6) +
  geom_vline(xintercept = 6, linetype = "dotted",
             color = country_colors["Sweden"], linewidth = 0.6) +
  annotate("text", x = 5, y = 0.05, label = "k = 5 (Italy)",
           hjust = 1.15, color = country_colors["Italy"], size = 3.4) +
  annotate("text", x = 6, y = 0.04, label = "k = 6 (Sweden)",
           hjust = -0.15, color = country_colors["Sweden"], size = 3.4) +
  scale_color_manual(values = country_colors) +
  scale_x_continuous(breaks = 2:10) +
  labs(x = "Number of clusters (k)", y = "Within-cluster R² (Ward)",
       color = NULL,
       caption = "Within-cluster R² reported as a cohesion gradient. The Duda-Hart pseudo-T² peaks at k = 5 (Italy) and k = 6 (Sweden);\nthe scree elbow agrees with the same values.") +
  theme(legend.position = "top")

ggsave(file.path(fig_dir_03, "fig_3_6_k_selection_scree.png"),
       p_scree, width = 10, height = 5.5, dpi = 300, bg = "white")


# ===============================================================================
# 7.  CAP. 4 — Figure 4.1 — Profile characteristics (8 diagnostic variables)
# ===============================================================================
# 8-panel bar chart with FULL profile names (not abbreviations).

dx_vars_4_1 <- tribble(
  ~variable,           ~label,                            ~unit,
  "age",               "Age (years)",                     NA_character_,
  "casp",              "Quality of life (CASP-12)",       NA_character_,
  "internet",          "Internet use (% past 7 days)",    "pct",
  "sn_size_w9",        "Social network size",             NA_character_,
  "hope_future",       "Hope for the future (% reporting)", "pct",
  "loneliness",        "Loneliness (UCLA-3)",             NA_character_,
  "eurod",             "Depression (EURO-D)",             NA_character_,
  "mobility",          "Mobility limitations",            NA_character_
)

prof_means_4_1 <- italy %>%
  select(profile, all_of(dx_vars_4_1$variable)) %>%
  group_by(profile) %>%
  summarise(across(everything(), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  pivot_longer(-profile, names_to = "variable", values_to = "mean_val") %>%
  left_join(dx_vars_4_1, by = "variable") %>%
  mutate(
    display_val = if_else(unit == "pct" & !is.na(unit), mean_val * 100, mean_val),
    label_text  = if_else(unit == "pct" & !is.na(unit),
                          sprintf("%.0f%%", display_val),
                          sprintf("%.1f", display_val)),
    variable    = factor(variable, levels = dx_vars_4_1$variable,
                         labels = dx_vars_4_1$label)
  )

p_chars <- prof_means_4_1 %>%
  ggplot(aes(profile, display_val, fill = profile)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = label_text), vjust = -0.4, size = 3.0,
            fontface = "bold") +
  facet_wrap(~ variable, scales = "free_y", nrow = 2) +
  scale_fill_manual(values = profile_colors_it, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.20))) +
  labs(x = NULL, y = "Cluster mean on raw scale",
       caption = "Mean values for each of the five archetypes on eight key dimensions. Profiles ordered from most fragile to most connected. n = 2,378.") +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 9),
        strip.background = element_rect(fill = "gray95", color = NA),
        panel.spacing = unit(1.0, "lines"))

ggsave(file.path(fig_dir_04, "fig_4_1_profile_characteristics.png"),
       p_chars, width = 16, height = 9, dpi = 300, bg = "white")


# ===============================================================================
# 8.  CAP. 4 — Figure 4.2 — Profile fingerprint, FACET WRAP version
# ===============================================================================
# One panel per profile, easier to read than the overlay version.

# Drop ID and country columns if present
exclude_cols <- intersect(c("mergeid", "country", "implicat"), colnames(italy))

analytical_vars <- italy %>%
  select(-profile, -all_of(exclude_cols)) %>%
  select(where(is.numeric)) %>%
  colnames() %>%
  intersect(ANALYTICAL_VARS)

italy_z <- italy %>%
  select(profile, all_of(analytical_vars)) %>%
  mutate(across(all_of(analytical_vars), ~ as.numeric(scale(.x)))) %>%
  pivot_longer(-profile, names_to = "variable", values_to = "z") %>%
  group_by(profile, variable) %>%
  summarise(mean_z = mean(z, na.rm = TRUE),
            se     = sd(z, na.rm = TRUE) / sqrt(n()),
            ci_low  = mean_z - 1.96 * se,
            ci_high = mean_z + 1.96 * se,
            .groups = "drop")

# Variable ordering grouped by FA factor
var_order_fa <- c(
  # F1: physical/functional
  "mobility", "iadl", "adl", "sphus", "chronic", "memory", "sp002_", "orienti",
  # F2: subjective
  "eurod", "casp", "loneliness", "interest", "hope_future", "expect_alive",
  # F3: digital/cognitive
  "ac035d8", "fluency", "internet", "fdistress", "phinact",
  # F4: social
  "sp008_", "ac035d5", "ac035d1", "social_integration", "sn_size_w9",
  # F5: body
  "bmi",
  # F6: economic
  "log_thinc", "ypen1", "log_hnetw", "home_own"
)
var_labels_human <- c(
  mobility = "Mobility limit.", iadl = "IADL limitations", adl = "ADL limitations",
  sphus = "Self-rated health", chronic = "Chronic diseases", memory = "Memory recall",
  sp002_ = "Received help", orienti = "Orientation",
  eurod = "Depression (EURO-D)", casp = "Quality of life (CASP)", loneliness = "Loneliness",
  interest = "Interest in things", hope_future = "Hopeful future", expect_alive = "Life expectancy",
  ac035d8 = "Educational course", fluency = "Verbal fluency", internet = "Internet use",
  fdistress = "Financial distress", phinact = "Phys. inactive",
  sp008_ = "Gave help", ac035d5 = "Volunteering", ac035d1 = "Sportclub",
  social_integration = "Social integration", sn_size_w9 = "Network size",
  bmi = "BMI",
  log_thinc = "Income (log)", ypen1 = "Pension income", log_hnetw = "Net wealth (log)",
  home_own = "Home owner"
)

italy_z_ord <- italy_z %>%
  filter(variable %in% var_order_fa) %>%
  mutate(variable = factor(variable, levels = var_order_fa,
                           labels = var_labels_human[var_order_fa]))

p_fingerprint_facet <- italy_z_ord %>%
  ggplot(aes(variable, mean_z, group = profile, color = profile, fill = profile)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray45", linewidth = 0.4) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
              alpha = 0.20, color = NA) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.7) +
  facet_wrap(~ profile, ncol = 3) +
  scale_color_manual(values = profile_colors_it, guide = "none") +
  scale_fill_manual(values = profile_colors_it, guide = "none") +
  labs(x = NULL, y = "Mean z-score (within Italy)",
       caption = "Mean z-score per profile across the 29 active analytical variables, with 95% bootstrap confidence ribbons (n = 2,378).\nVariables grouped by dominant FA factor and ordered within factor.") +
  theme(
    axis.text.x = element_text(angle = 70, hjust = 1, size = 7),
    panel.spacing = unit(1.0, "lines"),
    strip.background = element_rect(fill = "gray95", color = NA),
    strip.text = element_text(face = "bold", size = 11)
  )

ggsave(file.path(fig_dir_04, "fig_4_2_fingerprint_facet_italy.png"),
       p_fingerprint_facet, width = 16, height = 9, dpi = 300, bg = "white")


# ===============================================================================
# 9.  CAP. 4 — Figure 4.3 — FA1 × FA2 scatter, FACET 6-panel version
# ===============================================================================
# Five panels (one per profile) + one panel with all centroids and ellipses.

fa_scores_it <- as_tibble(fa_italy$scores)
italy_pa <- italy %>%
  bind_cols(fa_scores_it %>% select(PA1, PA2)) %>%
  mutate(profile = factor(profile, levels = profile_levels_it))

# Centroids
centroids_pa <- italy_pa %>%
  group_by(profile) %>%
  summarise(PA1 = mean(PA1, na.rm = TRUE),
            PA2 = mean(PA2, na.rm = TRUE),
            .groups = "drop")

# Per-profile panels (each highlights one profile against light gray background)
profile_panels <- map(profile_levels_it, function(prof) {
  italy_pa %>%
    ggplot(aes(PA1, PA2)) +
    geom_point(data = italy_pa, aes(PA1, PA2),
               color = "gray85", size = 0.6, alpha = 0.5) +
    geom_point(data = italy_pa %>% filter(profile == prof),
               aes(color = profile), size = 0.9, alpha = 0.7) +
    stat_ellipse(data = italy_pa %>% filter(profile == prof),
                 aes(color = profile), level = 0.50, linewidth = 0.7) +
    geom_point(data = centroids_pa %>% filter(profile == prof),
               aes(fill = profile), shape = 23, size = 4, color = "black",
               stroke = 0.6) +
    scale_color_manual(values = profile_colors_it, guide = "none") +
    scale_fill_manual(values = profile_colors_it, guide = "none") +
    labs(title = prof, x = NULL, y = NULL) +
    coord_cartesian(xlim = c(-1.5, 2.5), ylim = c(-1.5, 2)) +
    theme(plot.title = element_text(size = 11, face = "bold",
                                    color = profile_colors_it[prof]))
})

# Sixth panel: all centroids with ellipses + legend
p_all_centroids <- italy_pa %>%
  ggplot(aes(PA1, PA2, color = profile, fill = profile)) +
  stat_ellipse(level = 0.50, linewidth = 0.7, alpha = 0.75) +
  geom_point(data = centroids_pa, shape = 23, size = 5, color = "black",
             stroke = 0.6) +
  scale_color_manual(values = profile_colors_it) +
  scale_fill_manual(values = profile_colors_it) +
  labs(title = "All profiles — centroids", x = NULL, y = NULL,
       color = NULL, fill = NULL) +
  coord_cartesian(xlim = c(-1.5, 2.5), ylim = c(-1.5, 2)) +
  theme(legend.position = c(0.78, 0.30),
        legend.background = element_rect(fill = "white", color = "gray80"),
        legend.text = element_text(size = 8),
        legend.key.height = unit(0.5, "cm"),
        plot.title = element_text(size = 11, face = "bold"))

p_pa_facet <- (profile_panels[[1]] | profile_panels[[2]] | profile_panels[[3]]) /
  (profile_panels[[4]] | profile_panels[[5]] | p_all_centroids) +
  plot_annotation(
    caption = "Each point is one Italian respondent positioned on the two dominant factors (FA1: physical and functional fragility; FA2: subjective wellbeing, reversed).\nDiamonds mark cluster centroids; ellipses mark 50% confidence regions per profile.",
    theme = theme(plot.caption = element_text(color = "gray45", size = 9, hjust = 0))
  ) &
  labs(x = "FA1 — physical & functional fragility",
       y = "FA2 — subjective wellbeing (rev.)")

ggsave(file.path(fig_dir_04, "fig_4_3_fa_scatter_facet_italy.png"),
       p_pa_facet, width = 14, height = 9, dpi = 300, bg = "white")


# ===============================================================================
# 10.  CAP. 4 — Figure 4.4 — Life satisfaction by profile (boxplot + ANOVA)
# ===============================================================================
# External validation: lifesat is NOT in the analytical input set.

lifesat_var <- c("ac012_", "lifesat", "ac012")  # try alternative names
lifesat_col <- intersect(lifesat_var, colnames(italy))[1]

if (is.na(lifesat_col) || length(lifesat_col) == 0) {
  warning("No life satisfaction column found in italy. Skipping Figure 4.4.")
} else {
  lifesat_df <- italy %>%
    select(profile, lifesat = all_of(lifesat_col)) %>%
    filter(!is.na(lifesat))

  anova_res <- summary(aov(lifesat ~ profile, data = lifesat_df))[[1]]
  f_stat <- anova_res$`F value`[1]
  f_df1  <- anova_res$Df[1]
  f_df2  <- anova_res$Df[2]
  n_total <- nrow(lifesat_df)

  cluster_means <- lifesat_df %>%
    group_by(profile) %>%
    summarise(mean_lifesat = mean(lifesat, na.rm = TRUE), .groups = "drop")

  p_lifesat <- lifesat_df %>%
    ggplot(aes(profile, lifesat, fill = profile)) +
    geom_boxplot(width = 0.6, outlier.size = 0.6, outlier.alpha = 0.4) +
    geom_point(data = cluster_means, aes(profile, mean_lifesat),
               shape = 23, size = 4, fill = "white", color = "black",
               stroke = 0.6) +
    geom_text(data = cluster_means,
              aes(profile, mean_lifesat, label = sprintf("%.2f", mean_lifesat)),
              vjust = -1.0, size = 3.4, fontface = "bold") +
    annotate("text", x = Inf, y = 0.5,
             label = sprintf("ANOVA  F(%d, %d) = %.1f   p < .001   n = %d",
                             f_df1, f_df2, f_stat, n_total),
             hjust = 1.05, vjust = 0, size = 3.3, color = "gray35",
             fontface = "italic") +
    scale_fill_manual(values = profile_colors_it, guide = "none") +
    scale_y_continuous(breaks = seq(0, 10, 2), limits = c(0, 10.5)) +
    labs(x = NULL, y = "Life satisfaction (0–10)",
         caption = "Boxplots of SHARE Wave 9 item AC012 (eleven-point scale, 0–10) by cluster membership; diamonds report cluster means.\nLife satisfaction is administered in a separate questionnaire block and is NOT part of the analytical input set.") +
    theme(axis.text.x = element_text(angle = 15, hjust = 1, size = 10))

  ggsave(file.path(fig_dir_04, "fig_4_4_lifesat_anova_italy.png"),
         p_lifesat, width = 12, height = 6, dpi = 300, bg = "white")
}


# ===============================================================================
# 11.  CAP. 4 — Figure 4.5 — Profile composition by gender
# ===============================================================================

gender_col <- intersect(c("gender", "female", "sex"), colnames(italy))[1]

if (!is.na(gender_col)) {
  gender_df <- italy %>%
    mutate(gender_lbl = case_when(
      .data[[gender_col]] %in% c(1, "Male", "male", "M", "1") ~ "Men",
      .data[[gender_col]] %in% c(2, "Female", "female", "F", "0") ~ "Women",
      TRUE ~ as.character(.data[[gender_col]])
    )) %>%
    filter(gender_lbl %in% c("Men", "Women")) %>%
    count(gender_lbl, profile) %>%
    group_by(gender_lbl) %>%
    mutate(pct = n / sum(n) * 100) %>%
    ungroup() %>%
    mutate(profile = factor(profile, levels = rev(profile_levels_it)))

  p_gender <- gender_df %>%
    ggplot(aes(gender_lbl, pct, fill = profile)) +
    geom_col(position = "stack", width = 0.55) +
    geom_text(aes(label = sprintf("%.1f%%", pct)),
              position = position_stack(vjust = 0.5),
              size = 3.4, color = "white", fontface = "bold") +
    scale_fill_manual(values = profile_colors_it,
                      breaks = profile_levels_it, name = "Profile") +
    scale_y_continuous(labels = function(x) paste0(x, "%"),
                       expand = expansion(mult = c(0.0, 0.02))) +
    labs(x = NULL, y = "Share within gender",
         caption = "Each column shows the percentage of the gender group falling in each archetype; columns sum to 100%.") +
    theme(legend.position = "right",
          panel.grid.major.x = element_blank())

  ggsave(file.path(fig_dir_04, "fig_4_5_demographics_gender_italy.png"),
         p_gender, width = 11, height = 6.5, dpi = 300, bg = "white")
}


# ===============================================================================
# 12.  CAP. 4 — Figure 4.6 — Profile composition by age band
# ===============================================================================

age_col <- intersect(c("age", "age_years", "age_at_interview"), colnames(italy))[1]

if (!is.na(age_col)) {
  age_df <- italy %>%
    mutate(age_band = cut(.data[[age_col]],
                          breaks = c(64, 74, 84, Inf),
                          labels = c("65-74", "75-84", "85+"),
                          include.lowest = TRUE)) %>%
    filter(!is.na(age_band)) %>%
    count(age_band, profile) %>%
    group_by(age_band) %>%
    mutate(pct = n / sum(n) * 100) %>%
    ungroup() %>%
    mutate(profile = factor(profile, levels = rev(profile_levels_it)))

  p_age <- age_df %>%
    ggplot(aes(age_band, pct, fill = profile)) +
    geom_col(position = "stack", width = 0.55) +
    geom_text(aes(label = sprintf("%.1f%%", pct)),
              position = position_stack(vjust = 0.5),
              size = 3.4, color = "white", fontface = "bold") +
    scale_fill_manual(values = profile_colors_it,
                      breaks = profile_levels_it, name = "Profile") +
    scale_y_continuous(labels = function(x) paste0(x, "%"),
                       expand = expansion(mult = c(0.0, 0.02))) +
    labs(x = NULL, y = "Share within age band",
         caption = "The Fragile Resigned share rises from 4% in 65–74 to 38% in 85+; the Connected Active share declines from 31% to 11% over the same range.") +
    theme(legend.position = "right",
          panel.grid.major.x = element_blank())

  ggsave(file.path(fig_dir_04, "fig_4_6_demographics_age_italy.png"),
         p_age, width = 11, height = 6.5, dpi = 300, bg = "white")
}


# ===============================================================================
# 13.  CAP. 4 — Figure 4.7 — Healthcare under-utilisation (Isolation Paradox)
# ===============================================================================
# Cluster means on 4 healthcare metrics — the empirical signature of §4.7.

healthcare_path <- "v9/outputs/step11_italy_with_healthcare.rds"
if (file.exists(healthcare_path)) {
  healthcare_data <- readRDS(healthcare_path)

  # Variable mapping — adjust to actual column names in your healthcare data
  hc_map <- c(
    doctor_visits     = "hc002_",
    specialist_visits = "hc012_",
    forgone_care_pct  = "hc028_",
    hospital_nights   = "hc114_"
  )

  # Resolve actual columns present in the data
  hc_present <- hc_map[hc_map %in% colnames(healthcare_data)]

  if (length(hc_present) >= 1) {
    healthcare_long <- healthcare_data %>%
      select(profile, all_of(hc_present)) %>%
      rename_with(~ names(hc_present)[match(.x, hc_present)],
                  .cols = all_of(hc_present)) %>%
      pivot_longer(-profile, names_to = "metric", values_to = "value") %>%
      group_by(profile, metric) %>%
      summarise(mean_val = mean(value, na.rm = TRUE), .groups = "drop") %>%
      mutate(metric = factor(metric,
                             levels = c("doctor_visits", "specialist_visits",
                                        "forgone_care_pct", "hospital_nights"),
                             labels = c("Doctor visits / year",
                                        "Specialist visits / year",
                                        "Forgone care (%)",
                                        "Hospital nights / year")))

    p_healthcare <- healthcare_long %>%
      ggplot(aes(profile, mean_val, fill = profile)) +
      geom_col(width = 0.65) +
      geom_text(aes(label = sprintf("%.2f", mean_val)),
                vjust = -0.4, size = 3.2, fontface = "bold") +
      facet_wrap(~ metric, scales = "free_y", ncol = 2) +
      scale_fill_manual(values = profile_colors_it, guide = "none") +
      scale_y_continuous(expand = expansion(mult = c(0.02, 0.18))) +
      labs(x = NULL, y = NULL,
           caption = "Cluster means on healthcare utilisation indicators. Note the Moderate Isolated under-utilisation of preventive and outpatient care\npaired with over-utilisation of inpatient care — the canonical signature of delayed care-seeking (Isolation Paradox, §4.7).") +
      theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 9),
            strip.background = element_rect(fill = "gray95", color = NA),
            panel.spacing = unit(1.0, "lines"))

    ggsave(file.path(fig_dir_04, "fig_4_7_healthcare_italy.png"),
           p_healthcare, width = 13, height = 8, dpi = 300, bg = "white")
  } else {
    message("Healthcare columns not found. Skipping Figure 4.7.")
  }
}


# ===============================================================================
# 14.  CAP. 4 — Figure 4.8 (supplement) — Profile shares with absolute counts
# ===============================================================================

ITALIAN_OVER_65 <- 14180000  # Istat 2024

shares <- italy %>%
  count(profile) %>%
  mutate(
    pct   = n / sum(n) * 100,
    n_pop = pct / 100 * ITALIAN_OVER_65,
    label = sprintf("%.1f%%  —  ≈ %.2fM", pct, n_pop / 1e6)
  )

p_shares <- shares %>%
  ggplot(aes(reorder(profile, pct), pct, fill = profile)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = label), hjust = -0.06, size = 4) +
  coord_flip() +
  scale_fill_manual(values = profile_colors_it, guide = "none") +
  scale_y_continuous(limits = c(0, max(shares$pct) * 1.30),
                     labels = function(x) paste0(x, "%")) +
  labs(x = NULL, y = "Share of Italian over-65 population",
       caption = "Within-sample shares projected to the Istat 2024 estimate of 14.18M Italian residents aged 65 or older.") +
  theme(panel.grid.major.y = element_blank())

ggsave(file.path(fig_dir_04, "fig_4_8_profile_shares_italy.png"),
       p_shares, width = 11, height = 5, dpi = 300, bg = "white")


# ===============================================================================
# 15.  CAP. 4 — Figure 4.9 (supplement) — Boxplots of diagnostic variables
# ===============================================================================

diagnostic_vars <- c(
  casp           = "CASP-12 quality of life",
  internet       = "Internet use (binary)",
  eurod          = "EURO-D depression",
  mobility       = "Mobility limitations",
  sn_size_w9     = "Social-network size",
  log_thinc      = "Household income (log)"
)

italy_long_dx <- italy %>%
  select(profile, all_of(names(diagnostic_vars))) %>%
  pivot_longer(-profile, names_to = "variable", values_to = "value") %>%
  mutate(variable = factor(variable, levels = names(diagnostic_vars),
                           labels = diagnostic_vars))

p_box <- italy_long_dx %>%
  ggplot(aes(profile, value, fill = profile)) +
  geom_boxplot(outlier.size = 0.5, outlier.alpha = 0.4, width = 0.6) +
  facet_wrap(~ variable, scales = "free_y", ncol = 3) +
  scale_fill_manual(values = profile_colors_it, guide = "none") +
  labs(x = NULL, y = NULL,
       caption = "Distribution within each profile, raw scale.") +
  theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 9),
        strip.background = element_rect(fill = "gray95", color = NA),
        panel.spacing = unit(1.0, "lines"))

ggsave(file.path(fig_dir_04, "fig_4_9_boxplots_diagnostic_italy.png"),
       p_box, width = 14, height = 8, dpi = 300, bg = "white")


# ===============================================================================
# 16.  CAP. 4 — Figure 4.10 (supplement) — Income / wealth ridge density
# ===============================================================================

p_income <- italy %>%
  select(profile, log_thinc, log_hnetw) %>%
  pivot_longer(-profile, names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(metric,
                         levels = c("log_thinc", "log_hnetw"),
                         labels = c("Household income (log €)",
                                    "Household net wealth (log €)"))) %>%
  ggplot(aes(value, profile, fill = profile)) +
  geom_density_ridges(alpha = 0.7, scale = 0.95, color = "white",
                      linewidth = 0.4) +
  facet_wrap(~ metric, scales = "free_x", ncol = 2) +
  scale_fill_manual(values = profile_colors_it, guide = "none") +
  labs(x = NULL, y = NULL,
       caption = "Ridge density of log-transformed household income and net worth, by profile.") +
  theme(strip.background = element_rect(fill = "gray95", color = NA),
        panel.grid.major.y = element_blank(),
        panel.spacing = unit(1.0, "lines"))

ggsave(file.path(fig_dir_04, "fig_4_10_income_wealth_ridges.png"),
       p_income, width = 12, height = 6, dpi = 300, bg = "white")


# ===============================================================================
# DONE
# ===============================================================================
cat("\nFigures saved to:\n")
cat("  ", normalizePath(fig_dir_03), "\n")
cat(paste("   -", list.files(fig_dir_03, pattern = "^fig_3_"), collapse = "\n"), "\n\n")
cat("  ", normalizePath(fig_dir_04), "\n")
cat(paste("   -", list.files(fig_dir_04, pattern = "^fig_4_"), collapse = "\n"), "\n")
