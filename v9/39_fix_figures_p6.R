#!/usr/bin/env Rscript
# v9/39_fix_figures_p6.R
# Regenerate Fig 3.6 (LCA convergence) and Fig 4.5 (healthcare Italy)
# with the PROMPT 6 fixes:
#   - Fig 3.6: annotation "50% chance" -> "50% reference"
#   - Fig 4.5: GP-contacts panel -> Doctor-visits panel; forgone y-axis in %
# Originals are backed up with suffix .bak_pre-p6_2026-05-30.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(tidyr)
  library(tibble)
})

setwd("/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH")

# Per-cluster RdBu palette (red = fragile -> blue = high-resource),
# matching v9/26_chapter5_thematic_figures.R + 27_fix_fig_4_2_shares.R.
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

profile_colors_all <- c(profile_colors_it, profile_colors_se)

v9_03  <- "v9/figures/03_data_methods"
v9_04  <- "v9/figures/04_italy"
tex_03 <- "Invisible_Profiles_LaTeX_Overleaf/figures/03_data_methods"
tex_04 <- "Invisible_Profiles_LaTeX_Overleaf/figures/04_italy"

backup_suffix <- ".bak_pre-p6_2026-05-30"
for (f in c(file.path(v9_03,  "fig_kmeans_lca_convergence.png"),
            file.path(tex_03, "fig_kmeans_lca_convergence.png"),
            file.path(v9_04,  "fig_healthcare_italy.png"),
            file.path(tex_04, "fig_healthcare_italy.png"))) {
  bak <- paste0(f, backup_suffix)
  # Never overwrite an existing backup: the first run's .bak is the pristine
  # pre-P6 PNG and must not be clobbered by subsequent re-runs of this script.
  if (file.exists(f) && !file.exists(bak)) file.copy(f, bak, overwrite = FALSE)
}

# ===============================================================================
# FIG 3.6 — LCA convergence (annotation: "50% reference")
# ===============================================================================
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
) %>%
  mutate(profile = factor(profile,
                          levels = c(rev(profile_levels_it),
                                     rev(profile_levels_se))),
         country = factor(country, levels = c("Italy", "Sweden")))

p_conv <- conv_tbl %>%
  ggplot(aes(convergence * 100, profile, fill = profile)) +
  geom_col(width = 0.7) +
  geom_vline(xintercept = 50, linetype = "dashed",
             color = "gray45", linewidth = 0.4) +
  annotate("text", x = 50, y = Inf, label = "50% reference",
           hjust = -0.1, vjust = 1.5, color = "gray35",
           size = 3, fontface = "italic") +
  geom_text(aes(label = sprintf("%.1f%%", convergence * 100)),
            hjust = -0.15, size = 3.4) +
  facet_wrap(~ country, scales = "free_y") +
  scale_fill_manual(values = profile_colors_all, guide = "none") +
  scale_x_continuous(limits = c(0, 105),
                     labels = function(x) paste0(x, "%")) +
  labs(x = "Share of K-means cluster members in dominant LCA class",
       y = NULL,
       caption = "Bars: share of K-means cluster members whose LCA modal class coincides with the cluster. Dashed line at 50% = conservative majority reference (chance ~ 20% IT / 17% SE).") +
  theme_minimal(base_size = 12) +
  theme(strip.background = element_rect(fill = "gray95", color = NA),
        panel.grid.major.y = element_blank(),
        plot.caption = element_text(hjust = 0, size = 8.5,
                                    color = "gray30",
                                    margin = margin(t = 8)))

ggsave(file.path(v9_03, "fig_kmeans_lca_convergence.png"),
       p_conv, width = 13, height = 6.5, dpi = 300, bg = "white")
file.copy(file.path(v9_03, "fig_kmeans_lca_convergence.png"),
          file.path(tex_03, "fig_kmeans_lca_convergence.png"),
          overwrite = TRUE)

# ===============================================================================
# FIG 4.5 — Healthcare Italy (Doctor visits + forgone in %)
# ===============================================================================
italy_hc <- readRDS("v9/outputs/step11_italy_with_healthcare.rds")

healthcare_long <- italy_hc %>%
  mutate(profile     = factor(profile, levels = profile_levels_it),
         forgone_pct = forgone_any_cost * 100) %>%
  select(profile, doctor_visits, spec_contacts, forgone_pct, nights_hosp) %>%
  pivot_longer(-profile, names_to = "metric", values_to = "value") %>%
  group_by(profile, metric) %>%
  summarise(mean_val = mean(value, na.rm = TRUE), .groups = "drop") %>%
  mutate(metric = factor(metric,
                         levels = c("doctor_visits", "spec_contacts",
                                    "forgone_pct",  "nights_hosp"),
                         labels = c("Doctor visits / year",
                                    "Specialist contacts / year",
                                    "Forgone care for cost (%)",
                                    "Hospital nights / year")))

p_healthcare <- healthcare_long %>%
  ggplot(aes(profile, mean_val, fill = profile)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = ifelse(grepl("Forgone", metric),
                               sprintf("%.1f%%", mean_val),
                               sprintf("%.2f", mean_val))),
            vjust = -0.4, size = 3.2, fontface = "bold") +
  facet_wrap(~ metric, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = profile_colors_it, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.18))) +
  labs(x = NULL, y = NULL,
       caption = "Cluster means on four healthcare utilisation indicators (12-month reference). Forgone-care y-axis and bar labels expressed in percentage points.") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 9),
        strip.background = element_rect(fill = "gray95", color = NA),
        panel.spacing = unit(1.0, "lines"),
        plot.caption = element_text(hjust = 0, size = 8.5,
                                    color = "gray30",
                                    margin = margin(t = 8)))

ggsave(file.path(v9_04, "fig_healthcare_italy.png"),
       p_healthcare, width = 13, height = 8, dpi = 300, bg = "white")
file.copy(file.path(v9_04, "fig_healthcare_italy.png"),
          file.path(tex_04, "fig_healthcare_italy.png"),
          overwrite = TRUE)

# Report values used
cat("\n=== Fig 3.6 LCA convergence values ===\n")
conv_tbl %>% mutate(pct = sprintf("%.1f", convergence * 100)) %>%
  select(country, profile, pct) %>% print(n = Inf)

cat("\n=== Fig 4.5 healthcare-Italy cluster means ===\n")
healthcare_long %>% arrange(metric, profile) %>%
  mutate(value = sprintf("%.2f", mean_val)) %>%
  select(metric, profile, value) %>% print(n = Inf)

cat("\nFig 3.6 -> ", normalizePath(file.path(tex_03, "fig_kmeans_lca_convergence.png")), "\n")
cat("Fig 4.5 -> ", normalizePath(file.path(tex_04, "fig_healthcare_italy.png")), "\n")
