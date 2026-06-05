# ==============================================================================
# FIG 3.4 (label fig:ch3-fa-loadings) — FA loadings matrix, Italy + Sweden
# Regenerated with the variable-ordering fix: the two Sweden-only cultural items
# (ac035d4, ac035d7) are appended to the Italy-derived variable order so they
# receive labelled rows in the Sweden panel instead of collapsing into an "NA" row.
#
# Italy = step5 (PA, 29 vars); Sweden = step6 (ML, 31 vars).
# OUTPUT: Invisible_Profiles_LaTeX_Overleaf/figures/03_data_methods/fig_3_3_NEW_v3.png
#   (does not overwrite _v2; original in git/disk for rollback)
# ==============================================================================
suppressPackageStartupMessages({library(tidyverse)})
setwd("/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH")
source("v9/var_labels.R")  # canonical human-readable variable labels via relabel()

theme_thesis <- theme_minimal(base_family = "Times", base_size = 12) +
  theme(
    plot.caption     = element_text(color = "gray45", size = 9, hjust = 0, margin = margin(t = 8)),
    axis.title       = element_text(size = 11),
    axis.text        = element_text(size = 10, color = "gray25"),
    legend.title     = element_text(face = "bold", size = 10),
    legend.text      = element_text(size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "gray92", linewidth = 0.3),
    strip.text       = element_text(face = "bold", size = 11),
    plot.margin      = margin(14, 14, 14, 14))
theme_set(theme_thesis)

fa_italy  <- readRDS("v9/outputs/step5_italy_fa_results.rds")
fa_sweden <- readRDS("v9/outputs/step6_sweden_fa_results.rds")

build_loadings_df <- function(fa_obj, country) {
  L <- as.data.frame(unclass(fa_obj$loadings))
  L$variable <- rownames(L)
  L %>%
    pivot_longer(-variable, names_to = "factor", values_to = "loading") %>%
    mutate(country = country,
           loading_lbl  = if_else(abs(loading) >= 0.30, sprintf("%.2f", loading), ""),
           loading_show = if_else(abs(loading) >= 0.30, loading, NA_real_))
}

loadings_long <- bind_rows(
  build_loadings_df(fa_italy,  "Italy"),
  build_loadings_df(fa_sweden, "Sweden"))

# Order variables by their dominant factor in Italy (shared order across panels)
var_order <- loadings_long %>%
  filter(country == "Italy") %>%
  group_by(variable) %>%
  slice_max(abs(loading), n = 1) %>%
  arrange(factor, desc(abs(loading))) %>%
  pull(variable)

# FIX: append Sweden-only variables so every Swedish row is labelled (no "NA" row)
sweden_vars <- loadings_long %>% filter(country == "Sweden") %>% distinct(variable) %>% pull(variable)
sweden_only <- setdiff(sweden_vars, var_order)
var_order   <- c(var_order, sweden_only)
cat("Sweden-only variables appended to ordering:", paste(sweden_only, collapse = ", "), "\n")

p_fa <- loadings_long %>%
  mutate(variable = factor(variable, levels = rev(var_order)),
         country  = factor(country, levels = c("Italy", "Sweden"))) %>%
  ggplot(aes(factor, variable, fill = loading_show)) +
  geom_tile(color = "white", linewidth = 0.4) +
  geom_text(aes(label = loading_lbl, color = abs(loading) > 0.6), size = 2.9) +
  scale_color_manual(values = c(`FALSE` = "black", `TRUE` = "white"),
                     guide = "none", na.value = "black") +
  scale_fill_gradient2(low = "#3B528B", mid = "white", high = "#C72E2E",
                       midpoint = 0, limits = c(-1, 1), na.value = "gray97",
                       breaks = c(-1, -0.5, 0, 0.5, 1)) +
  scale_y_discrete(labels = function(v) relabel(v)) +  # codes -> readable labels
  facet_wrap(~ country, scales = "free_x") +
  labs(x = "Factor", y = NULL, fill = "Loading",
       caption = "Cells with |loading| < 0.30 are suppressed for readability. Both countries: 6-factor solution, varimax rotation.\nVariable ordering follows the dominant Italian factor for cross-country comparability. KMO = 0.832 (IT); 0.808 (SE); Bartlett p < 0.001 in both countries.") +
  theme(panel.grid = element_blank(),
        strip.background = element_rect(fill = "gray95", color = NA),
        legend.position = "right",
        axis.text.y = element_text(size = 9))

out <- "Invisible_Profiles_LaTeX_Overleaf/figures/03_data_methods/fig_3_3_NEW_v3.png"
ggsave(out, p_fa, width = 14, height = 11, dpi = 300, bg = "white")

# Verify no NA row: every Sweden variable must be a level present in var_order
se_missing <- setdiff(sweden_vars, var_order)
cat("Sweden variables still missing from ordering (expect none):",
    if (length(se_missing) == 0) "NONE" else paste(se_missing, collapse = ", "), "\n")
cat("Total variable rows in panel:", length(var_order), "\n")
cat("Saved:", out, "\n")
