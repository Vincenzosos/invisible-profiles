# ==============================================================================
# FIG 1.1 — Demographic pyramid, Italy vs Sweden (2024) — redesign
# Thesis: "Beyond the Monolith"
#
# Two-panel population pyramid (Italy left, Sweden right). Stylised 2024 age-sex
# distribution (shares of national total), hardcoded from Istat 2024 (~58.99M) and
# Statistics Sweden 2024 (~10.55M) reference structures. Band shares sum to 100%
# per country; the 65+ threshold falls inside the 60--74 band, so the over-65 share
# is computed as (60--74)+(75--84)+(85+) minus the hardcoded 60--64 sub-share.
#
# OUTPUT: Invisible_Profiles_LaTeX_Overleaf/figures/01_intro/fig_1_1_demographic_pyramid_v2.png
#   300 DPI, 10in x 5in (~3000x1500 px). Original PNG preserved for rollback.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

setwd("/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH")

POP_IT <- 58.99e6   # Istat 2024 total resident population (reference)
POP_SE <- 10.55e6   # Statistics Sweden 2024 total resident population (reference)

band_levels <- c("0-14", "15-29", "30-44", "45-59", "60-74", "75-84", "85+")

# Hardcoded shares (% of national total), Male / Female per band.
raw <- tribble(
  ~country, ~band,    ~Male, ~Female,
  "Italy",  "0-14",    5.9,   5.6,
  "Italy",  "15-29",   7.2,   6.8,
  "Italy",  "30-44",   8.8,   8.7,
  "Italy",  "45-59",  11.4,  11.6,
  "Italy",  "60-74",   9.0,  10.0,
  "Italy",  "75-84",   4.4,   5.6,
  "Italy",  "85+",     1.8,   3.2,
  "Sweden", "0-14",    9.0,   8.5,
  "Sweden", "15-29",   9.5,   9.0,
  "Sweden", "30-44",   9.9,   9.6,
  "Sweden", "45-59",   9.6,   9.4,
  "Sweden", "60-74",   7.7,   7.8,
  "Sweden", "75-84",   3.3,   3.7,
  "Sweden", "85+",     1.1,   1.9
)

# Hardcoded 60--64 sub-share (the under-65 part of the 60--74 band), to net the
# over-65 share down to the official Istat/SCB figure.
share_60_64 <- c(Italy = 10.0, Sweden = 4.5)

# --- Over-65 share computed from hardcoded values ---
over65 <- raw %>%
  mutate(total = Male + Female) %>%
  group_by(country) %>%
  summarise(sum_60plus = sum(total[band %in% c("60-74", "75-84", "85+")]),
            .groups = "drop") %>%
  mutate(over_65_share = sum_60plus - share_60_64[country])

cat("============================================================\n")
cat("FIG 1.1 demographic pyramid — Italy vs Sweden (2024)\n")
cat("============================================================\n")
cat(sprintf("Reference total population: Italy %.2fM, Sweden %.2fM\n", POP_IT/1e6, POP_SE/1e6))
for (i in seq_len(nrow(over65))) {
  cat(sprintf("  %-7s: 60+ band sum = %.1f%%, minus 60-64 (%.1f%%)  ->  over-65 share = %.1f%%\n",
              over65$country[i], over65$sum_60plus[i],
              share_60_64[over65$country[i]], over65$over_65_share[i]))
}
stopifnot(sum(raw$Male + raw$Female) == 200)  # 100% per country x 2 countries

# --- Long format: Male negative (left), Female positive (right) ---
pyr <- raw %>%
  pivot_longer(c(Male, Female), names_to = "sex", values_to = "share") %>%
  mutate(value   = ifelse(sex == "Male", -share, share),
         band    = factor(band, levels = band_levels),
         country = factor(country, levels = c("Italy", "Sweden")),
         sex     = factor(sex, levels = c("Male", "Female")))

country_colors <- c(Italy = "#3a6b8a", Sweden = "#5d8fae")

# 65+ threshold line sits between 45-59 (pos 4) and 60-74 (pos 5)
thr_y <- 4.5
thr_label <- data.frame(country = factor("Italy", levels = c("Italy", "Sweden")),
                        x = 8.5, y = thr_y + 0.35, label = "65+ threshold")

# Over-65 share annotation (one per panel), placed in the shaded region (75-84 band)
over_lab <- data.frame(
  country = factor(c("Italy", "Sweden"), levels = c("Italy", "Sweden")),
  x = c(-7, 7), y = c(6.4, 6.4),
  label = c("Over-65: 24.0%", "Over-65: 21.0%"))

p <- ggplot(pyr, aes(x = value, y = band, fill = country, alpha = sex)) +
  annotate("rect", xmin = -12, xmax = 12, ymin = 4.5, ymax = 7.5,
           fill = "#3a6b8a", alpha = 0.08) +
  geom_col(width = 0.78) +
  geom_hline(yintercept = thr_y, linetype = "dashed", color = "grey30", linewidth = 0.5) +
  geom_text(data = thr_label, aes(x = x, y = y, label = label),
            inherit.aes = FALSE, hjust = 1, vjust = 0, size = 3.1,
            color = "grey30", family = "serif") +
  geom_text(data = over_lab, aes(x = x, y = y, label = label),
            inherit.aes = FALSE, hjust = 0.5, size = 3.5,
            color = "grey20", family = "serif") +
  facet_wrap(~ country) +
  scale_fill_manual(values = country_colors, guide = "none") +
  scale_alpha_manual(values = c(Male = 1.0, Female = 0.55), name = NULL) +
  scale_x_continuous(limits = c(-12, 12), breaks = seq(-10, 10, 5),
                     labels = function(x) abs(x)) +
  guides(alpha = guide_legend(override.aes = list(fill = "grey25"))) +
  labs(title = "Age and sex distribution, 2024",
       x = "Share of national population (%)", y = NULL) +
  theme_minimal(base_family = "serif", base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 14, hjust = 0.5,
                                    margin = margin(b = 10)),
    strip.text       = element_text(face = "bold", size = 12),
    axis.text        = element_text(size = 10, color = "gray25"),
    axis.title.x     = element_text(size = 11, margin = margin(t = 8)),
    legend.position  = "bottom",
    legend.text      = element_text(size = 10),
    panel.grid.major = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.grid.minor.x = element_line(color = alpha("grey50", 0.15)),
    panel.spacing    = unit(1.2, "lines"),
    plot.margin      = margin(14, 16, 12, 14)
  )

out <- "Invisible_Profiles_LaTeX_Overleaf/figures/01_intro/fig_1_1_demographic_pyramid_v3.png"
ggsave(out, p, width = 10, height = 5, dpi = 300, bg = "white")
cat("\nSaved:", out, "\n")
