# ===============================================================================
# FIX FIG 4.2 (Italia shares) — numeri pipeline corretti
# Vincenzo Pio Silvestri — May 2026
#
# Il file fig_4_8_NEW.png attualmente referenziato da chapter4.tex usa numeri
# obsoleti (pre-pipeline rewrite). Lo rigeneriamo con i numeri verified pipeline:
#   Fragile Resigned    13.2%  ≈ 1.88M
#   Fragile Depressed   26.8%  ≈ 3.79M
#   Moderate Isolated   26.9%  ≈ 3.81M
#   Traditional Social   7.7%  ≈ 1.10M
#   Connected Active    25.4%  ≈ 3.60M
#
# Run:
#   setwd("~/Desktop/SHARE DATASET/DATASET RESEARCH")
#   source("v9/27_fix_fig_4_2_shares.R")
# ===============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
})

to_num <- function(x) {
  if (inherits(x, "haven_labelled")) x <- haven::zap_labels(x)
  as.numeric(unclass(x))
}

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

italy <- readRDS("v9/outputs/step7_italy_with_clusters.rds")
italy$profile <- factor(italy$profile, levels = profile_levels_it)
ITALIAN_OVER_65 <- 14180000  # Istat 2024

# Weighted post-hoc projection (Trentini #8): bar = within-sample (unweighted) share,
# label = weighted national projection using SHARE Wave 9 design weight cciw_w9.
wt <- haven::read_dta("_share_data/sharew9_rel9-0-0_gv_weights.dta")
wt <- data.frame(mergeid = as.character(wt$mergeid),
                 cciw_w9 = as.numeric(haven::zap_labels(wt$cciw_w9)))
italy <- italy %>%
  mutate(mergeid = as.character(mergeid)) %>%
  left_join(wt, by = "mergeid")
w_total <- sum(italy$cciw_w9, na.rm = TRUE)

shares <- italy %>%
  group_by(profile) %>%
  summarise(n = n(), w_sum = sum(cciw_w9, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    pct          = 100 * n / sum(n),                        # unweighted (bar height)
    weighted_pct = 100 * w_sum / w_total,
    M_weighted   = weighted_pct / 100 * ITALIAN_OVER_65 / 1e6,
    label        = sprintf("%.1f%% — ≈%.2fM", pct, M_weighted)
  )

cat("Pipeline shares for Cap 4 Fig 4.2 (unweighted bar + weighted M projection):\n")
print(as.data.frame(shares))

p <- shares %>%
  ggplot(aes(reorder(profile, pct), pct, fill = profile)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = label), hjust = -0.15, size = 4) +
  coord_flip() +
  scale_fill_manual(values = profile_colors_it, guide = "none") +
  scale_y_continuous(limits = c(0, max(shares$pct) * 1.45),
                     labels = function(x) paste0(x, "%")) +
  labs(x = NULL, y = "Share of Italian over-65 analytical sample",
       caption = NULL) +
  theme(panel.grid.major.y = element_blank())

# Sovrascrivo il file referenziato dal chapter4.tex
out_path <- "Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_4_8_NEW.png"
ggsave(out_path, p, width = 11, height = 5, dpi = 300, bg = "white")
cat("\nSaved (overwritten):", out_path, "\n")
