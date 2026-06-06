# ==============================================================================
# FIG 3.5 — K-SELECTION SCREE (within-cluster R^2 = between/total SS, k=2..10)
# Recreates the deployed ad-hoc figure with two fixes:
#   (a) Sweden annotation R^2 = 0.211 (was 0.210), to match Tab 3.3 / Tab 7.1
#   (b) restore the x-axis title "Number of clusters (k)"
# Curve is recomputed from the standardised analytical matrices (seed 42).
#
# OUTPUT: Invisible_Profiles_LaTeX_Overleaf/figures/03_data_methods/fig_kselection_scree.png
# ==============================================================================

suppressMessages({ library(dplyr); library(ggplot2) })

data_path <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"

# --- analytical variable blocks (same as steps 2/4/7/8) ---------------------
health_vars  <- c("sphus","chronic","adl","iadl","mobility","eurod","bmi","phinact")
econ_vars    <- c("log_thinc","log_hnetw","ypen1","home_own","fdistress")
digital_vars <- c("internet","ac035d1","ac035d5","ac035d8",
                  "sp002_","sp008_","sn_size_w9","social_integration",
                  "ac035d4","ac035d7")
cog_vars     <- c("fluency","memory","orienti")
subj_vars    <- c("loneliness","casp","hope_future","interest","expect_alive")
all_31       <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

it_std <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_std.rds"))
se_std <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_std.rds"))

# within-cluster R^2 = betweenss / totss, for k = 2..10, on active vars
r2_curve <- function(df) {
  sds    <- sapply(df[, all_31], sd)
  active <- all_31[is.finite(sds) & sds > 0]   # Italy drops ac035d4, ac035d7
  X <- as.matrix(df[, active])
  set.seed(42)
  sapply(2:10, function(k) {
    km <- kmeans(X, centers = k, nstart = 50, iter.max = 200)
    km$betweenss / km$totss
  })
}

it_r2 <- r2_curve(it_std)
se_r2 <- r2_curve(se_std)
cat("Italy  R2 k2..10:", paste(sprintf("%.3f", it_r2), collapse = " "), "\n")
cat("Sweden R2 k2..10:", paste(sprintf("%.3f", se_r2), collapse = " "), "\n")
cat(sprintf("Italy k5 = %.3f ; Sweden k6 = %.3f\n", it_r2[5-1], se_r2[6-1]))

dat <- bind_rows(
  data.frame(country = "Italy",  k = 2:10, R2 = it_r2),
  data.frame(country = "Sweden", k = 2:10, R2 = se_r2)
) %>% mutate(country = factor(country, levels = c("Italy", "Sweden")))

country_colors <- c(Italy = "#1F3A6E", Sweden = "#7FB3DB")  # deep navy / light blue

hi <- data.frame(
  country = factor(c("Italy", "Sweden"), levels = c("Italy", "Sweden")),
  k  = c(5, 6),
  R2 = c(it_r2[5-1], se_r2[6-1])
)

p <- ggplot(dat, aes(k, R2, colour = country)) +
  # chosen-k guides
  geom_vline(xintercept = 5, linetype = "dashed", colour = "grey55", alpha = 0.7, linewidth = 0.4) +
  geom_vline(xintercept = 6, linetype = "dashed", colour = country_colors["Sweden"], alpha = 0.9, linewidth = 0.4) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2.6) +
  geom_point(data = hi, size = 6) +          # highlighted chosen-k points
  # annotations (R^2 values fixed to the canonical table figures)
  annotate("segment", x = 3.05, y = 0.305, xend = 4.9, yend = it_r2[5-1] + 0.002,
           colour = "grey45", linewidth = 0.3) +
  annotate("text", x = 3.0, y = 0.315, hjust = 0, vjust = 0, lineheight = 0.95,
           label = "k = 5 (Italy)\nR² = 0.248", colour = country_colors["Italy"],
           fontface = "bold", size = 4.2, family = "Times") +
  annotate("segment", x = 6.1, y = se_r2[6-1] - 0.002, xend = 7.4, yend = 0.165,
           colour = "grey45", linewidth = 0.3) +
  annotate("text", x = 7.5, y = 0.16, hjust = 0, vjust = 1, lineheight = 0.95,
           label = "k = 6 (Sweden)\nR² = 0.211", colour = country_colors["Sweden"],
           fontface = "bold", size = 4.2, family = "Times") +
  scale_colour_manual(values = country_colors, name = NULL) +
  scale_x_continuous(breaks = 2:10) +
  labs(x = "Number of clusters (k)",
       y = "Within-cluster R² (between SS / total SS)") +
  theme_minimal(base_family = "Times", base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "gray92", linewidth = 0.3),
    axis.title.x = element_text(margin = margin(t = 8)),
    axis.title.y = element_text(margin = margin(r = 8)),
    legend.position = c(0.93, 0.12),
    legend.background = element_rect(fill = "white", colour = NA),
    plot.margin = margin(10, 14, 10, 10)
  )

out <- file.path(data_path, "Invisible_Profiles_LaTeX_Overleaf",
                 "figures", "03_data_methods", "fig_kselection_scree.png")
ggsave(out, p, width = 12, height = 5.5, dpi = 300, bg = "white")
cat("Saved:", out, "\n")
