# ===============================================================================
# CHAPTER 5 — THEMATIC FIGURES (binary fragility, digital saturation, rotation)
# Vincenzo Pio Silvestri — MSc EMIT — May 2026
#
# Generates three figures designed for the Cap 5 substantive argument:
#   Fig 5.A  Binary vs graduated fragility structure (IT vs SE)
#   Fig 5.B  Digital saturation cut (IT vs SE internet% bars, reference at 75%)
#   Fig 5.C  Age-prosperity rotation (SE shows CW vs AR crossover; IT parallel decline)
#
# Output:  Invisible_Profiles_LaTeX_Overleaf/figures/05_sweden/
#   fig_5_A_binary_fragility.png
#   fig_5_B_digital_saturation.png
#   fig_5_C_age_prosperity_rotation.png
#
# Run:
#   setwd("~/Desktop/SHARE DATASET/DATASET RESEARCH")
#   source("v9/26_chapter5_thematic_figures.R")
# ===============================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("ggrepel", quietly = TRUE)) install.packages("ggrepel")
  library(tidyverse)
  library(patchwork)
  library(haven)
  library(scales)
  library(ggrepel)
})

to_num <- function(x) {
  if (inherits(x, "haven_labelled")) x <- haven::zap_labels(x)
  as.numeric(unclass(x))
}

# -------------------------------------------------------------------------------
# THEME + PALETTES
# -------------------------------------------------------------------------------
theme_thesis <- theme_minimal(base_family = "Times", base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 13, hjust = 0,
                                    margin = margin(b = 6)),
    plot.subtitle    = element_text(color = "gray40", size = 11, hjust = 0),
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

profile_levels_it <- c("Fragile Resigned", "Fragile Depressed",
                       "Moderate Isolated", "Traditional Social",
                       "Connected Active")
profile_colors_it <- c(
  "Fragile Resigned"   = "#A6190E",
  "Fragile Depressed"  = "#E07A5F",
  "Moderate Isolated"  = "#8C8C8C",
  "Traditional Social" = "#9DBDD9",
  "Connected Active"   = "#1B3F73"
)

profile_levels_se <- c("Fragile", "Social Decline", "Moderate",
                       "Asset Rich", "Wealthy Digital", "Connected Wealthy")
profile_colors_se <- c(
  "Fragile"           = "#A6190E",
  "Social Decline"    = "#E07A5F",
  "Moderate"          = "#8C8C8C",
  "Asset Rich"        = "#9DBDD9",
  "Wealthy Digital"   = "#4A82B5",
  "Connected Wealthy" = "#1B3F73"
)

fig_dir <- "Invisible_Profiles_LaTeX_Overleaf/figures/05_sweden"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# -------------------------------------------------------------------------------
# LOAD + COERCE
# -------------------------------------------------------------------------------
italy   <- readRDS("v9/outputs/step7_italy_with_clusters.rds")
sweden  <- readRDS("v9/outputs/step8_sweden_with_clusters.rds")

cat("Loaded italy n =", nrow(italy), "; sweden n =", nrow(sweden), "\n")

key_cols <- c("age", "internet", "mobility", "adl", "iadl", "sphus", "chronic",
              "eurod", "loneliness")
for (cc in key_cols) {
  if (cc %in% names(italy))  italy[[cc]]  <- to_num(italy[[cc]])
  if (cc %in% names(sweden)) sweden[[cc]] <- to_num(sweden[[cc]])
}

italy$profile  <- factor(italy$profile,  levels = profile_levels_it)
sweden$profile <- factor(sweden$profile, levels = profile_levels_se)

# ===============================================================================
# FIG 5.A — BINARY VS GRADUATED FRAGILITY STRUCTURE
# ===============================================================================
# Composite fragility index = mean of z(mobility) + z(adl) + z(iadl), within country
# Each profile centroid plotted on the composite axis. SE shows 1+5 split,
# IT shows 2+3 split.
# ===============================================================================
cat("\n[A] Fig 5.A — Binary fragility structure\n")

build_burden_2d <- function(df, country) {
  # Two separate composite indices, both z-scored within country (high = more burden)
  func_vars <- c("mobility", "adl", "iadl")
  affect_vars <- c("eurod", "loneliness")
  z <- df %>%
    select(profile, all_of(c(func_vars, affect_vars))) %>%
    mutate(across(all_of(c(func_vars, affect_vars)), ~ as.numeric(scale(.x))))
  z$func_z   <- rowMeans(z[, func_vars],   na.rm = TRUE)
  z$affect_z <- rowMeans(z[, affect_vars], na.rm = TRUE)
  z %>%
    group_by(profile) %>%
    summarise(
      func_mean   = mean(func_z,   na.rm = TRUE),
      affect_mean = mean(affect_z, na.rm = TRUE),
      n           = n(),
      .groups = "drop"
    ) %>%
    mutate(country = country)
}

burd_it <- build_burden_2d(italy,  "Italy")
burd_se <- build_burden_2d(sweden, "Sweden")

cat("Italy burden centroids (functional, affective):\n");  print(burd_it)
cat("Sweden burden centroids (functional, affective):\n"); print(burd_se)

burd_all <- bind_rows(burd_it, burd_se) %>%
  mutate(country = factor(country, levels = c("Italy", "Sweden")))

profile_colors_all <- c(profile_colors_it, profile_colors_se)

# Pre-compute per-point label nudges to push crowded lower-left labels outward
burd_all$nudge_x <- 0
burd_all$nudge_y <- 0
# Italy non-fragile (lower-left): nudge labels down and slightly out
burd_all$nudge_y[burd_all$profile == "Connected Active"]   <- -0.08
burd_all$nudge_x[burd_all$profile == "Connected Active"]   <-  0.10
burd_all$nudge_y[burd_all$profile == "Traditional Social"] <- -0.05
burd_all$nudge_x[burd_all$profile == "Traditional Social"] <- -0.20
burd_all$nudge_y[burd_all$profile == "Moderate Isolated"]  <- -0.15
burd_all$nudge_x[burd_all$profile == "Moderate Isolated"]  <- -0.05
# Sweden non-fragile clustered: spread vertically
burd_all$nudge_y[burd_all$profile == "Wealthy Digital"]    <-  0.06
burd_all$nudge_x[burd_all$profile == "Wealthy Digital"]    <-  0.18
burd_all$nudge_y[burd_all$profile == "Asset Rich"]         <-  0.00
burd_all$nudge_x[burd_all$profile == "Asset Rich"]         <-  0.18
burd_all$nudge_y[burd_all$profile == "Social Decline"]     <- -0.05
burd_all$nudge_x[burd_all$profile == "Social Decline"]     <- -0.18
burd_all$nudge_y[burd_all$profile == "Connected Wealthy"]  <- -0.10
burd_all$nudge_x[burd_all$profile == "Connected Wealthy"]  <-  0.05
# Italian Fragile Depressed: pull label up-left for clarity
burd_all$nudge_y[burd_all$profile == "Fragile Depressed"]  <-  0.10
burd_all$nudge_x[burd_all$profile == "Fragile Depressed"]  <- -0.12

# Single overlaid panel: shape distinguishes country, color distinguishes profile,
# text labels each cluster centroid (with white background for readability).
p_5_A <- burd_all %>%
  ggplot(aes(func_mean, affect_mean, color = profile, shape = country)) +
  # Highlight the upper half: where fragile clusters sit (drawn first, behind axes)
  annotate("rect", xmin = -1.05, xmax = 2.05, ymin = 0, ymax = 1.45,
           fill = "#A6190E", alpha = 0.04) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray70", linewidth = 0.4) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray70", linewidth = 0.4) +
  annotate("text", x = -0.95, y = 1.36,
           label = "Fragile region (above-mean burden on either axis)",
           hjust = 0, size = 3.2, color = "#A6190E", fontface = "italic") +
  geom_point(size = 5.5, stroke = 0.6, alpha = 0.95) +
  ggrepel::geom_label_repel(
    aes(label = profile),
    size = 3.2, fontface = "bold",
    seed = 42,
    force = 5, force_pull = 0.5,
    box.padding = 0.45, point.padding = 0.4,
    label.padding = 0.18, label.size = 0,
    fill = alpha("white", 0.85),
    nudge_x = burd_all$nudge_x, nudge_y = burd_all$nudge_y,
    min.segment.length = 0,
    segment.color = "gray55", segment.size = 0.25,
    max.overlaps = Inf,
    show.legend = FALSE) +
  scale_color_manual(values = profile_colors_all, guide = "none") +
  scale_shape_manual(values = c("Italy" = 16, "Sweden" = 17),
                     name = NULL) +
  scale_x_continuous(limits = c(-1.05, 2.05), breaks = seq(-1, 2, 0.5)) +
  scale_y_continuous(limits = c(-1.0, 1.45), breaks = seq(-1, 1.4, 0.5)) +
  labs(x = "Functional burden (mean of z(mobility), z(ADL), z(IADL), within country)",
       y = "Affective burden (mean of z(EURO-D), z(loneliness), within country)",
       caption = "Cluster centroids on the joint functional-affective burden plane, both z-scored within country (high = more burden). Italy (circles) places\ntwo profiles in the upper region: Fragile Resigned in the upper-right corner (high on both) and Fragile Depressed in the upper-left (high affective\nburden, modest functional burden) -- the graduated fragility structure. Sweden (triangles) places a single profile, Fragile, in the upper-right;\nthe five non-fragile profiles cluster near the origin -- the binary fragility structure that distinguishes Sweden from Italy.") +
  theme(legend.position = "top",
        legend.title = element_text(face = "bold", size = 10),
        legend.text  = element_text(size = 10))

ggsave(file.path(fig_dir, "fig_5_A_binary_fragility.png"),
       p_5_A, width = 14, height = 8.5, dpi = 300, bg = "white")
cat("    saved\n")


# ===============================================================================
# FIG 5.B — DIGITAL SATURATION CUT
# ===============================================================================
# Bar chart: 5 IT bars + 6 SE bars, internet% sorted descending within country.
# Reference line at 75%. The visual narrative: the cut means different things
# in the two countries.
# ===============================================================================
cat("\n[B] Fig 5.B — Digital saturation cut\n")

internet_it <- italy %>%
  group_by(profile) %>%
  summarise(internet_pct = 100 * mean(internet, na.rm = TRUE), .groups = "drop") %>%
  mutate(country = "Italy")

internet_se <- sweden %>%
  group_by(profile) %>%
  summarise(internet_pct = 100 * mean(internet, na.rm = TRUE), .groups = "drop") %>%
  mutate(country = "Sweden")

cat("Italy internet% by profile:\n");  print(internet_it)
cat("Sweden internet% by profile:\n"); print(internet_se)

internet_all <- bind_rows(internet_it, internet_se) %>%
  mutate(country = factor(country, levels = c("Italy", "Sweden")))

# Combined palette per profile (dispatched by country panel)
profile_colors_all <- c(profile_colors_it, profile_colors_se)

p_5_B <- internet_all %>%
  group_by(country) %>%
  arrange(country, internet_pct) %>%
  mutate(profile = factor(profile,
                          levels = unique(profile))) %>%
  ungroup() %>%
  ggplot(aes(profile, internet_pct, fill = profile)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 75, linetype = "dashed",
             color = "#C72E2E", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.1f%%", internet_pct)),
            vjust = -0.5, size = 3.4, fontface = "bold", color = "gray20") +
  facet_wrap(~ country, scales = "free_x") +
  scale_fill_manual(values = profile_colors_all, guide = "none") +
  scale_y_continuous(limits = c(0, 110), breaks = seq(0, 100, 25),
                     labels = function(x) paste0(x, "%"),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(x = NULL, y = "Internet use (% past 7 days)",
       caption = "Cluster means on the binary internet-use indicator (SHARE Wave 9). Dashed reference line at 75%.\nIn Sweden only the Fragile cluster lies below 75%; in Italy no profile reaches 75% (Connected Active at 74.8%).\nThe digital cut in Sweden tracks the functional-fragility line; in Italy it tracks the resource gradient.") +
  theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 9),
        strip.background = element_rect(fill = "gray95", color = NA),
        panel.spacing = unit(1.2, "lines"),
        panel.grid.major.x = element_blank())

ggsave(file.path(fig_dir, "fig_5_B_digital_saturation.png"),
       p_5_B, width = 14, height = 6.5, dpi = 300, bg = "white")
cat("    saved\n")


# ===============================================================================
# FIG 5.C — AGE-PROSPERITY ROTATION
# ===============================================================================
# Two panels: (a) Italy and (b) Sweden, each with the two well-resourced profiles
# plotted as % of age band across 65-74, 75-84, 85+.
# Sweden shows crossover (CW down, AR up); Italy shows parallel decline (CA + TS).
# ===============================================================================
cat("\n[C] Fig 5.C — Age-prosperity rotation\n")

age_band_share <- function(df, country, well_resourced_profiles) {
  df %>%
    mutate(age_band = cut(age,
                          breaks = c(64, 74, 84, Inf),
                          labels = c("65-74", "75-84", "85+"),
                          include.lowest = TRUE)) %>%
    filter(!is.na(age_band)) %>%
    count(age_band, profile) %>%
    group_by(age_band) %>%
    mutate(pct = 100 * n / sum(n)) %>%
    ungroup() %>%
    filter(profile %in% well_resourced_profiles) %>%
    mutate(country = country)
}

it_well <- c("Connected Active", "Traditional Social")
se_well <- c("Connected Wealthy", "Asset Rich")

age_it <- age_band_share(italy,  "Italy",  it_well)
age_se <- age_band_share(sweden, "Sweden", se_well)

cat("Italy well-resourced shares by age band:\n");  print(age_it)
cat("Sweden well-resourced shares by age band:\n"); print(age_se)

p_it_age <- age_it %>%
  mutate(profile = factor(profile, levels = it_well)) %>%
  ggplot(aes(age_band, pct, color = profile, group = profile)) +
  geom_line(linewidth = 1.4) +
  geom_point(size = 4) +
  geom_text(aes(label = sprintf("%.0f%%", pct)),
            vjust = -1.0, size = 3.4, fontface = "bold", show.legend = FALSE) +
  scale_color_manual(values = profile_colors_it, name = NULL) +
  scale_y_continuous(limits = c(0, 50), breaks = seq(0, 50, 10),
                     labels = function(x) paste0(x, "%")) +
  labs(x = NULL, y = "Share within age band",
       title = "(a) Italy — parallel decline of both well-resourced profiles") +
  theme(legend.position = "top",
        panel.grid.major.x = element_blank(),
        plot.title = element_text(size = 11, face = "bold", color = "gray25"))

p_se_age <- age_se %>%
  mutate(profile = factor(profile, levels = se_well)) %>%
  ggplot(aes(age_band, pct, color = profile, group = profile)) +
  geom_line(linewidth = 1.4) +
  geom_point(size = 4) +
  # Labels split by series so the two lines do not cover each other at the
  # 75-84 crossover (Connected Wealthy 23% vs Asset Rich 22%): the declining
  # Connected Wealthy is labelled above its points, the rising Asset Rich below.
  geom_text(data = function(d) dplyr::filter(d, profile == "Connected Wealthy"),
            aes(label = sprintf("%.0f%%", pct)),
            vjust = -1.1, size = 3.4, fontface = "bold", show.legend = FALSE) +
  geom_text(data = function(d) dplyr::filter(d, profile == "Asset Rich"),
            aes(label = sprintf("%.0f%%", pct)),
            vjust = 1.9, size = 3.4, fontface = "bold", show.legend = FALSE) +
  scale_color_manual(values = profile_colors_se, name = NULL) +
  scale_y_continuous(limits = c(0, 50), breaks = seq(0, 50, 10),
                     labels = function(x) paste0(x, "%")) +
  labs(x = NULL, y = NULL,
       title = "(b) Sweden — rotation: Connected Wealthy down, Asset Rich up") +
  theme(legend.position = "top",
        panel.grid.major.x = element_blank(),
        plot.title = element_text(size = 11, face = "bold", color = "gray25"))

p_5_C <- (p_it_age | p_se_age) +
  plot_annotation(
    caption = "Share of each well-resourced profile within age band, computed on respondents in the analytical sample (Italy n = 2,378; Sweden n = 1,787).\nIn Italy both Connected Active and Traditional Social decline in parallel with age. In Sweden Connected Wealthy contracts (41%->7%) while Asset Rich expands (14%->31%):\nthe high-resource pole rotates from a digital-engagement anchor (young-old) to a wealth-accumulation anchor (oldest-old). No analogous rotation in Italy.",
    theme = theme(plot.caption = element_text(color = "gray45", size = 9, hjust = 0))
  )

ggsave(file.path(fig_dir, "fig_5_C_age_prosperity_rotation.png"),
       p_5_C, width = 14, height = 6, dpi = 300, bg = "white")
cat("    saved\n")


# ===============================================================================
# DONE
# ===============================================================================
cat("\n============================================================\n")
cat("THEMATIC FIGURES — DONE\n")
cat("============================================================\n")
cat("Saved to:", normalizePath(fig_dir), "\n")
cat(paste("  -", list.files(fig_dir, pattern = "^fig_5_[ABC]_")), sep = "\n")
cat("\n")
