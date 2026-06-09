# ===============================================================================
# CHAPTER 5 FIGURES — SWEDEN TYPOLOGY
# Vincenzo Pio Silvestri — MSc EMIT — May 2026
#
# Generates 5 figures for Cap 5 (parallel structure to Cap 4):
#   Fig 5.1  Profile characteristics, 8 dimensions (parallel of Fig 4.1)
#   Fig 5.2  Profile fingerprint, faceted z-scores (parallel of Fig 4.3)
#   Fig 5.3  Factor 1 x Factor 2 scatter, 6 + centroids (parallel of Fig 4.4)
#   Fig 5.4  Life satisfaction boxplot + ANOVA (parallel of Fig 4.5)
#   Fig 5.5  Demographics: gender + age band combined (parallel of Fig 4.6)
#
# All figures saved to:
#   Invisible_Profiles_LaTeX_Overleaf/figures/05_sweden/
#
# Run from R/RStudio:
#   setwd("~/Desktop/SHARE DATASET/DATASET RESEARCH")
#   source("v9/25_chapter5_figures.R")
# ===============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
  library(haven)
})

# Helper: coerce haven_labelled vectors (.dta) to numeric safely
to_num <- function(x) {
  if (inherits(x, "haven_labelled")) x <- haven::zap_labels(x)
  as.numeric(unclass(x))
}

# -------------------------------------------------------------------------------
# THEME — matches Cap 4 visual style
# -------------------------------------------------------------------------------
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

# -------------------------------------------------------------------------------
# PALETTE — RdBu gradient mirroring Cap 4 (red = fragile, blue = high resource)
# -------------------------------------------------------------------------------
profile_levels_se <- c("Fragile", "Social Decline", "Moderate",
                       "Asset Rich", "Wealthy Digital", "Connected Wealthy")
profile_colors_se <- c(
  "Fragile"           = "#A6190E",  # deep red
  "Social Decline"    = "#E07A5F",  # coral
  "Moderate"          = "#8C8C8C",  # grey
  "Asset Rich"        = "#9DBDD9",  # light blue
  "Wealthy Digital"   = "#4A82B5",  # medium blue
  "Connected Wealthy" = "#1B3F73"   # dark blue
)

# -------------------------------------------------------------------------------
# OUTPUT DIR
# -------------------------------------------------------------------------------
fig_dir_05 <- "Invisible_Profiles_LaTeX_Overleaf/figures/05_sweden"
dir.create(fig_dir_05, recursive = TRUE, showWarnings = FALSE)

# -------------------------------------------------------------------------------
# LOAD DATA + COERCE LABELLED COLUMNS
# -------------------------------------------------------------------------------
sweden    <- readRDS("v9/outputs/step8_sweden_with_clusters.rds")
fa_sweden <- readRDS("v9/outputs/step6_sweden_fa_results.rds")

cat("Loaded sweden: n =", nrow(sweden), "\n")

# Coerce labelled cols to numeric
labelled_cols <- c("age", "casp", "internet", "sn_size_w9", "loneliness",
                   "hope_future", "eurod", "mobility", "adl", "iadl",
                   "lifesat", "gender", "interest", "expect_alive",
                   "social_integration", "fluency", "memory", "orienti",
                   "sphus", "chronic", "bmi", "phinact",
                   "log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress",
                   "ac035d1", "ac035d4", "ac035d5", "ac035d7", "ac035d8",
                   "sp002_", "sp008_")
for (cc in labelled_cols) {
  if (cc %in% names(sweden)) sweden[[cc]] <- to_num(sweden[[cc]])
}

sweden$profile <- factor(sweden$profile, levels = profile_levels_se)


# ===============================================================================
# FIG 5.1 — Profile characteristics (8 diagnostic variables, 6 bars each)
# ===============================================================================
cat("\n[1/5] Fig 5.1 — Profile characteristics\n")

dx_vars_5_1 <- tribble(
  ~variable,           ~label,                              ~unit,
  "age",               "Age (years)",                       NA_character_,
  "casp",              "Quality of life (CASP-12)",         NA_character_,
  "internet",          "Internet use (% past 7 days)",      "pct",
  "sn_size_w9",        "Social network size",               NA_character_,
  "hope_future",       "Hope for the future (% reporting)", "pct",
  "loneliness",        "Loneliness (UCLA-3)",               NA_character_,
  "eurod",             "Depression (EURO-D)",               NA_character_,
  "mobility",          "Mobility limitations",              NA_character_
)

prof_means_5_1 <- sweden %>%
  select(profile, all_of(dx_vars_5_1$variable)) %>%
  group_by(profile) %>%
  summarise(across(everything(), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
  pivot_longer(-profile, names_to = "variable", values_to = "mean_val") %>%
  left_join(dx_vars_5_1, by = "variable") %>%
  mutate(
    display_val = if_else(unit == "pct" & !is.na(unit), mean_val * 100, mean_val),
    label_text  = if_else(unit == "pct" & !is.na(unit),
                          sprintf("%.0f%%", display_val),
                          sprintf("%.1f", display_val)),
    variable    = factor(variable, levels = dx_vars_5_1$variable,
                         labels = dx_vars_5_1$label)
  )

p_5_1 <- prof_means_5_1 %>%
  ggplot(aes(profile, display_val, fill = profile)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = label_text), vjust = -0.4, size = 2.8,
            fontface = "bold") +
  facet_wrap(~ variable, scales = "free_y", nrow = 2) +
  scale_fill_manual(values = profile_colors_se, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.20))) +
  labs(x = NULL, y = "Cluster mean on raw scale",
       caption = "Mean values for each of the six archetypes on eight key dimensions. Profiles ordered from most fragile (left) to most connected (right). n = 1,787.") +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size = 8),
        strip.background = element_rect(fill = "gray95", color = NA),
        panel.spacing = unit(1.0, "lines"))

ggsave(file.path(fig_dir_05, "fig_5_1_profile_characteristics_sweden.png"),
       p_5_1, width = 16, height = 9, dpi = 300, bg = "white")
cat("    saved\n")


# ===============================================================================
# FIG 5.2 — Profile fingerprint, faceted (6 panels, mean z-scores per profile)
# ===============================================================================
cat("[2/5] Fig 5.2 — Fingerprint faceted\n")

ANALYTICAL_VARS <- c(
  "sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact",
  "log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress",
  "internet", "sn_size_w9", "social_integration",
  "ac035d1", "ac035d4", "ac035d5", "ac035d7", "ac035d8",
  "sp002_", "sp008_",
  "fluency", "memory", "orienti",
  "casp", "loneliness", "hope_future", "interest", "expect_alive"
)

analytical_vars_se <- intersect(ANALYTICAL_VARS, names(sweden))
analytical_vars_se <- analytical_vars_se[
  sapply(sweden[, analytical_vars_se], function(x) is.numeric(x) && var(x, na.rm = TRUE) > 1e-10)
]

sweden_z <- sweden %>%
  select(profile, all_of(analytical_vars_se)) %>%
  mutate(across(all_of(analytical_vars_se), ~ as.numeric(scale(.x)))) %>%
  pivot_longer(-profile, names_to = "variable", values_to = "z") %>%
  group_by(profile, variable) %>%
  summarise(mean_z = mean(z, na.rm = TRUE),
            se     = sd(z, na.rm = TRUE) / sqrt(n()),
            ci_low  = mean_z - 1.96 * se,
            ci_high = mean_z + 1.96 * se,
            .groups = "drop")

# Variable ordering grouped by FA factor (parallel to Italy fig)
var_order_fa <- c(
  "mobility", "iadl", "adl", "sphus", "chronic", "memory", "sp002_", "orienti",
  "eurod", "casp", "loneliness", "interest", "hope_future", "expect_alive",
  "ac035d8", "fluency", "internet", "fdistress", "phinact",
  "sp008_", "ac035d5", "ac035d1", "ac035d4", "ac035d7",
  "social_integration", "sn_size_w9",
  "bmi",
  "log_thinc", "ypen1", "log_hnetw", "home_own"
)
var_labels_human <- c(
  mobility = "Mobility limit.", iadl = "IADL limitations", adl = "ADL limitations",
  sphus = "Self-rated health", chronic = "Chronic diseases", memory = "Memory recall",
  sp002_ = "Received help", orienti = "Orientation",
  eurod = "Depression (EURO-D)", casp = "Quality of life (CASP)",
  loneliness = "Loneliness", interest = "Interest in things",
  hope_future = "Hopeful future", expect_alive = "Life expectancy",
  ac035d8 = "Educational course", fluency = "Verbal fluency",
  internet = "Internet use", fdistress = "Financial distress",
  phinact = "Phys. inactive",
  sp008_ = "Gave help", ac035d5 = "Volunteering", ac035d1 = "Sportclub",
  ac035d4 = "Religious org.", ac035d7 = "Political org.",
  social_integration = "Social integration", sn_size_w9 = "Network size",
  bmi = "BMI",
  log_thinc = "Income (log)", ypen1 = "Pension income",
  log_hnetw = "Net wealth (log)", home_own = "Home owner"
)

var_order_use <- intersect(var_order_fa, analytical_vars_se)

sweden_z_ord <- sweden_z %>%
  filter(variable %in% var_order_use) %>%
  mutate(variable = factor(variable, levels = var_order_use,
                           labels = var_labels_human[var_order_use]))

p_5_2 <- sweden_z_ord %>%
  ggplot(aes(variable, mean_z, group = profile, color = profile, fill = profile)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray45", linewidth = 0.4) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
              alpha = 0.20, color = NA) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.7) +
  facet_wrap(~ profile, ncol = 3) +
  scale_color_manual(values = profile_colors_se, guide = "none") +
  scale_fill_manual(values = profile_colors_se, guide = "none") +
  labs(x = NULL, y = "Mean z-score (within Sweden)",
       caption = "Mean z-score per profile across the active analytical variables, with 95% bootstrap confidence ribbons (n = 1,787).\nVariables grouped by dominant FA factor and ordered within factor.") +
  theme(
    axis.text.x = element_text(angle = 70, hjust = 1, size = 7),
    panel.spacing = unit(1.0, "lines"),
    strip.background = element_rect(fill = "gray95", color = NA),
    strip.text = element_text(face = "bold", size = 11)
  )

ggsave(file.path(fig_dir_05, "fig_5_2_fingerprint_facet_sweden.png"),
       p_5_2, width = 16, height = 9, dpi = 300, bg = "white")
cat("    saved\n")


# ===============================================================================
# FIG 5.3 — Factor 1 x Factor 2 scatter (6 individual + 1 all-centroids)
# ===============================================================================
cat("[3/5] Fig 5.3 — FA scatter facet\n")

# Always recompute to ensure we have both scores AND loadings (per identification)
if (!requireNamespace("psych", quietly = TRUE)) install.packages("psych")
suppressPackageStartupMessages(library(psych))

sweden_std <- readRDS("v9/outputs/step4_sweden_std.rds")
active <- intersect(ANALYTICAL_VARS, names(sweden_std))
active <- active[sapply(sweden_std[, active],
                        function(x) is.numeric(x) && var(x, na.rm = TRUE) > 1e-10)]
X_se <- sweden_std[, active] %>% as.matrix()
X_se <- X_se[complete.cases(X_se), ]

set.seed(42)
fa_refit <- suppressWarnings(psych::fa(X_se, nfactors = 6, fm = "pa",
                                       rotate = "varimax", scores = "regression",
                                       warnings = FALSE))

L <- unclass(fa_refit$loadings)  # variables x factors
cat("    Factor loadings on key indicator variables:\n")
key_indicators <- intersect(c("mobility", "iadl", "adl", "eurod", "loneliness", "casp"),
                            rownames(L))
print(round(L[key_indicators, ], 2))

# Substantive Factor 1 = the one with HIGHEST sum of |loadings| on physical (mobility, iadl, adl)
# Substantive Factor 2 = the one with HIGHEST sum of |loadings| on subjective burden (eurod, loneliness)
phys_vars <- intersect(c("mobility", "iadl", "adl", "sphus", "chronic"), rownames(L))
subj_vars <- intersect(c("eurod", "loneliness"), rownames(L))

phys_score <- colSums(abs(L[phys_vars, , drop = FALSE]))
subj_score <- colSums(abs(L[subj_vars, , drop = FALSE]))

f1_idx <- which.max(phys_score)
# Per Factor 2: prendiamo la migliore tra le restanti
phys_excluded <- subj_score
phys_excluded[f1_idx] <- -Inf
f2_idx <- which.max(phys_excluded)

f1_name <- colnames(L)[f1_idx]
f2_name <- colnames(L)[f2_idx]

cat(sprintf("    Substantive Factor 1 (physical fragility) = %s (phys-load score %.2f)\n",
            f1_name, phys_score[f1_idx]))
cat(sprintf("    Substantive Factor 2 (subjective burden)  = %s (subj-load score %.2f)\n",
            f2_name, subj_score[f2_idx]))

fa_scores_se <- as_tibble(fa_refit$scores)

# Verifica row alignment
if (nrow(fa_scores_se) != nrow(sweden)) {
  warning(sprintf("Row mismatch: fa_scores n=%d, sweden n=%d. Truncating to min.",
                  nrow(fa_scores_se), nrow(sweden)))
  n_min <- min(nrow(fa_scores_se), nrow(sweden))
  fa_scores_se <- fa_scores_se[seq_len(n_min), ]
  sweden_fa_base <- sweden[seq_len(n_min), ]
} else {
  sweden_fa_base <- sweden
}

# Flip Factor 1 sign so HIGH = MORE FRAGILE if loading on mobility is negative
flip_f1 <- if (L["mobility", f1_idx] < 0) -1 else 1
flip_f2 <- if (L["eurod", f2_idx] < 0) -1 else 1
cat(sprintf("    Sign flip: Factor 1 x %d, Factor 2 x %d (so high = more fragile / more burden)\n",
            flip_f1, flip_f2))

sweden_fa <- sweden_fa_base %>%
  bind_cols(
    PA1 = flip_f1 * fa_scores_se[[f1_name]],
    PA2 = flip_f2 * fa_scores_se[[f2_name]]
  ) %>%
  mutate(profile = factor(profile, levels = profile_levels_se))

centroids_fa <- sweden_fa %>%
  group_by(profile) %>%
  summarise(PA1 = mean(PA1, na.rm = TRUE),
            PA2 = mean(PA2, na.rm = TRUE),
            .groups = "drop")

# Per-profile panels
profile_panels <- map(profile_levels_se, function(prof) {
  sweden_fa %>%
    ggplot(aes(PA1, PA2)) +
    geom_point(data = sweden_fa, aes(PA1, PA2),
               color = "gray85", size = 0.6, alpha = 0.5) +
    geom_point(data = sweden_fa %>% filter(profile == prof),
               aes(color = profile), size = 0.9, alpha = 0.7) +
    stat_ellipse(data = sweden_fa %>% filter(profile == prof),
                 aes(color = profile), level = 0.50, linewidth = 0.7) +
    geom_point(data = centroids_fa %>% filter(profile == prof),
               aes(fill = profile), shape = 23, size = 4, color = "black",
               stroke = 0.6) +
    scale_color_manual(values = profile_colors_se, guide = "none") +
    scale_fill_manual(values = profile_colors_se, guide = "none") +
    labs(title = prof, x = NULL, y = NULL) +
    coord_cartesian(xlim = c(-1.5, 2.5), ylim = c(-1.5, 2)) +
    theme(plot.title = element_text(size = 11, face = "bold",
                                    color = profile_colors_se[prof]))
})

# All-centroids panel
p_all_centroids <- sweden_fa %>%
  ggplot(aes(PA1, PA2, color = profile, fill = profile)) +
  stat_ellipse(level = 0.50, linewidth = 0.7, alpha = 0.75) +
  geom_point(data = centroids_fa, shape = 23, size = 5, color = "black",
             stroke = 0.6) +
  scale_color_manual(values = profile_colors_se) +
  scale_fill_manual(values = profile_colors_se) +
  labs(title = "All profiles — centroids", x = NULL, y = NULL,
       color = NULL, fill = NULL) +
  coord_cartesian(xlim = c(-1.5, 2.5), ylim = c(-1.5, 2)) +
  theme(legend.position = c(0.78, 0.30),
        legend.background = element_rect(fill = "white", color = "gray80"),
        legend.text = element_text(size = 7),
        legend.key.height = unit(0.4, "cm"),
        plot.title = element_text(size = 11, face = "bold"))

# 2 rows x 4 cols layout: 6 individual + centroids + spacer
p_5_3 <- (profile_panels[[1]] | profile_panels[[2]] | profile_panels[[3]] | profile_panels[[4]]) /
  (profile_panels[[5]] | profile_panels[[6]] | p_all_centroids | plot_spacer()) +
  plot_annotation(
    caption = "Each point is one Swedish respondent positioned on the two dominant factors (Factor 1: physical and functional fragility; Factor 2: subjective wellbeing).\nDiamonds mark cluster centroids; ellipses mark 50% confidence regions per profile.",
    theme = theme(plot.caption = element_text(color = "gray45", size = 9, hjust = 0))
  ) &
  labs(x = "Factor 1 — physical & functional fragility",
       y = "Factor 2 — subjective wellbeing")

ggsave(file.path(fig_dir_05, "fig_5_3_fa_scatter_facet_sweden.png"),
       p_5_3, width = 16, height = 8.5, dpi = 300, bg = "white")
cat("    saved\n")


# ===============================================================================
# FIG 5.4 — Life satisfaction by profile (boxplot + ANOVA F-statistic)
# ===============================================================================
cat("[4/5] Fig 5.4 — Lifesat boxplot\n")

lifesat_df <- sweden %>%
  select(profile, lifesat) %>%
  filter(!is.na(lifesat))

anova_res <- summary(aov(lifesat ~ profile, data = lifesat_df))[[1]]
f_stat <- anova_res$`F value`[1]
f_df1  <- anova_res$Df[1]
f_df2  <- anova_res$Df[2]
n_total <- nrow(lifesat_df)

cluster_means <- lifesat_df %>%
  group_by(profile) %>%
  summarise(mean_lifesat = mean(lifesat, na.rm = TRUE), .groups = "drop")

p_5_4 <- lifesat_df %>%
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
  scale_fill_manual(values = profile_colors_se, guide = "none") +
  scale_y_continuous(breaks = seq(0, 10, 2), limits = c(0, 10.5)) +
  labs(x = NULL, y = "Life satisfaction (0-10)",
       caption = "Boxplots of SHARE Wave 9 item AC012 (eleven-point scale, 0-10) by cluster membership; diamonds report cluster means.\nLife satisfaction is administered in a separate questionnaire block and is NOT part of the analytical input set.") +
  theme(axis.text.x = element_text(angle = 15, hjust = 1, size = 10))

ggsave(file.path(fig_dir_05, "fig_5_4_lifesat_anova_sweden.png"),
       p_5_4, width = 12, height = 6, dpi = 300, bg = "white")
cat(sprintf("    saved (F = %.2f)\n", f_stat))


# ===============================================================================
# FIG 5.5 — Demographics: gender + age band combined (parallel of Fig 4.6)
# ===============================================================================
cat("[5/5] Fig 5.5 — Demographics gender + age combined\n")

# Gender panel
gender_df <- sweden %>%
  mutate(gender_lbl = case_when(
    gender == 1 ~ "Men",
    gender == 2 ~ "Women",
    TRUE        ~ NA_character_
  )) %>%
  filter(!is.na(gender_lbl)) %>%
  count(gender_lbl, profile) %>%
  group_by(gender_lbl) %>%
  mutate(pct = n / sum(n) * 100) %>%
  ungroup() %>%
  mutate(profile = factor(profile, levels = rev(profile_levels_se)))

p_gender <- gender_df %>%
  ggplot(aes(gender_lbl, pct, fill = profile)) +
  geom_col(position = "stack", width = 0.55) +
  geom_text(aes(label = sprintf("%.1f%%", pct)),
            position = position_stack(vjust = 0.5),
            size = 3.0, color = "white", fontface = "bold") +
  scale_fill_manual(values = profile_colors_se,
                    breaks = profile_levels_se, name = "Profile") +
  scale_y_continuous(labels = function(x) paste0(x, "%"),
                     expand = expansion(mult = c(0.0, 0.02))) +
  labs(x = NULL, y = "Share within gender",
       title = "(a) By gender") +
  theme(legend.position = "none",
        panel.grid.major.x = element_blank())

# Age band panel
age_df <- sweden %>%
  mutate(age_band = cut(age,
                        breaks = c(64, 74, 84, Inf),
                        labels = c("65-74", "75-84", "85+"),
                        include.lowest = TRUE)) %>%
  filter(!is.na(age_band)) %>%
  count(age_band, profile) %>%
  group_by(age_band) %>%
  mutate(pct = n / sum(n) * 100) %>%
  ungroup() %>%
  mutate(profile = factor(profile, levels = rev(profile_levels_se)))

p_age <- age_df %>%
  ggplot(aes(age_band, pct, fill = profile)) +
  geom_col(position = "stack", width = 0.55) +
  geom_text(aes(label = sprintf("%.0f%%", pct)),
            position = position_stack(vjust = 0.5),
            size = 3.0, color = "white", fontface = "bold") +
  scale_fill_manual(values = profile_colors_se,
                    breaks = profile_levels_se, name = "Profile") +
  scale_y_continuous(labels = function(x) paste0(x, "%"),
                     expand = expansion(mult = c(0.0, 0.02))) +
  labs(x = NULL, y = "Share within age band",
       title = "(b) By age band (65-74, 75-84, 85+)") +
  theme(legend.position = "right",
        panel.grid.major.x = element_blank())

p_5_5 <- (p_gender | p_age) +
  plot_layout(widths = c(0.85, 1.5)) +
  plot_annotation(
    caption = "Each column shows the percentage of the demographic group falling in each archetype; columns sum to 100%.\nPanel (b): the Fragile share rises from 6% in 65-74 to 37% in 85+; the Connected Wealthy share declines from 41% to 7% over the same range.",
    theme = theme(plot.caption = element_text(color = "gray45", size = 9, hjust = 0))
  )

ggsave(file.path(fig_dir_05, "fig_5_5_demographics_sweden.png"),
       p_5_5, width = 13, height = 6.5, dpi = 300, bg = "white")
cat("    saved\n")


# ===============================================================================
# DONE
# ===============================================================================
cat("\n============================================================\n")
cat("CHAPTER 5 FIGURES — DONE\n")
cat("============================================================\n")
cat("Saved to:", normalizePath(fig_dir_05), "\n\n")
cat(paste("  -", list.files(fig_dir_05, pattern = "^fig_5_")), sep = "\n")
cat("\n")
