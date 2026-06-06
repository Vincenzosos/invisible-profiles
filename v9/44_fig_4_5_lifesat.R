# ==============================================================================
# FIG 4.5 — Life satisfaction by Italian profile (boxplots + jitter + mean).
# Adds profile labels on the x-axis (previously absent). Recomputed from the
# deployed cluster data so values are unchanged.
# OUTPUT: Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_lifesat_anova_italy.png
# ==============================================================================
suppressMessages({ library(ggplot2); library(dplyr) })

base <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"
prof <- c("Fragile Resigned","Fragile Depressed","Moderate Isolated",
          "Traditional Social","Connected Active")
pal  <- c("Fragile Resigned"="#C8302A","Fragile Depressed"="#E27858",
          "Moderate Isolated"="#888888","Traditional Social"="#4A8FBE",
          "Connected Active"="#143E72")

d <- readRDS(file.path(base, "v9/outputs/step7_italy_with_clusters.rds")) %>%
  filter(!is.na(lifesat)) %>%
  mutate(profile = factor(profile, levels = prof))

mus <- d %>% group_by(profile) %>% summarise(m = mean(lifesat), .groups = "drop")
av  <- summary(aov(lifesat ~ profile, data = d))[[1]]
Fst <- av[["F value"]][1]; df1 <- av[["Df"]][1]; df2 <- av[["Df"]][2]; n <- nrow(d)
cat("means:\n"); print(mus); cat(sprintf("F(%d,%d)=%.1f  n=%d\n", df1, df2, Fst, n))

set.seed(42)
p <- ggplot(d, aes(profile, lifesat)) +
  geom_jitter(aes(colour = profile), width = 0.28, height = 0.18,
              alpha = 0.18, size = 0.7) +
  geom_boxplot(aes(fill = profile), width = 0.62, outlier.shape = NA,
               alpha = 0.85, colour = "grey25") +
  geom_point(data = mus, aes(profile, m), shape = 23, size = 5,
             fill = "white", colour = "grey20", stroke = 1) +
  geom_text(data = mus, aes(profile, m, label = sprintf("%.2f", m)),
            vjust = -1.4, size = 4, family = "Times") +
  annotate("text", x = 5.45, y = 0.4, hjust = 1, fontface = "italic",
           family = "Times", size = 4.2,
           label = sprintf("ANOVA  F(%d, %d) = %.1f    p < .001    n = %s",
                           df1, df2, Fst, formatC(n, format = "d", big.mark = ","))) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_colour_manual(values = pal, guide = "none") +
  scale_x_discrete(labels = gsub(" ", "\n", prof)) +
  scale_y_continuous(breaks = seq(0, 10, 2), limits = c(-0.3, 10.3)) +
  labs(x = NULL, y = "Life satisfaction (0-10)") +
  theme_minimal(base_family = "Times", base_size = 13) +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor = element_blank(),
        axis.text.x = element_text(size = 11, lineheight = 0.9),
        plot.margin = margin(10, 14, 6, 8))

out <- file.path(base, "Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_lifesat_anova_italy.png")
ggsave(out, p, width = 13.7, height = 6.6, dpi = 200, bg = "white")
cat("Saved:", out, "\n")
