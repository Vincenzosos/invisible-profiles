# ==============================================================================
# FIG 4.1 — Italian profile signatures, 8 bar panels.
# Adds a shared profile legend at the bottom (bars were colour-coded by profile
# but had neither legend nor x labels). Values are the deployed figures, copied
# verbatim (no recomputation) so the data is unchanged.
# OUTPUT: Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_4_1_NEW.png
# ==============================================================================
suppressMessages({ library(ggplot2); library(patchwork) })

base <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"
prof <- c("Fragile Resigned","Fragile Depressed","Moderate Isolated",
          "Traditional Social","Connected Active")
pal  <- c("Fragile Resigned"="#C8302A","Fragile Depressed"="#E27858",
          "Moderate Isolated"="#888888","Traditional Social"="#4A8FBE",
          "Connected Active"="#143E72")

panels <- list(
  list("Age (years)",                  c(81.5,77.3,72.8,73.8,73.9), FALSE),
  list("Quality of life (CASP12)",     c(27.8,30.7,36.8,38.5,37.8), FALSE),
  list("Internet use (% past 7 days)", c(8.6,17.3,34.1,65.8,74.8),  TRUE),
  list("Social network size",          c(2.4,2.2,2.3,2.6,3.0),      FALSE),
  list("Hope for the future (%)",      c(45.4,67.6,92.0,89.7,90.9), TRUE),
  list("Loneliness (UCLA-3)",          c(6.2,5.4,3.6,3.8,3.7),      FALSE),
  list("Depression (EURO-D)",          c(6.1,4.2,1.2,1.7,2.1),      FALSE),
  list("Mobility limitations",         c(6.2,2.7,0.6,0.9,1.1),      FALSE)
)

mk <- function(name, vals, pct) {
  d <- data.frame(profile = factor(prof, levels = prof), value = vals)
  lab <- if (pct) sprintf("%.1f%%", vals) else sprintf("%.1f", vals)
  ggplot(d, aes(profile, value, fill = profile)) +
    geom_col(width = 0.80) +
    geom_text(aes(label = lab), vjust = -0.4, size = 3.0, family = "Times",
              colour = "grey15") +
    scale_fill_manual(values = pal, breaks = prof, name = NULL) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.16))) +
    labs(x = NULL, y = name) +
    theme_minimal(base_family = "Times", base_size = 11) +
    theme(axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          panel.grid.major.x = element_blank(),
          panel.grid.minor = element_blank(),
          axis.title.y = element_text(size = 10.5, margin = margin(r = 4)),
          plot.margin = margin(6, 8, 2, 4))
}

plots <- lapply(panels, function(p) mk(p[[1]], p[[2]], p[[3]]))
combined <- wrap_plots(plots, nrow = 2) +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom",
        legend.text = element_text(family = "Times", size = 11)) &
  guides(fill = guide_legend(nrow = 1, override.aes = list(size = 0)))

out <- file.path(base, "Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_4_1_NEW.png")
ggsave(out, combined, width = 13, height = 6.6, dpi = 220, bg = "white")
cat("Saved:", out, "\n")
