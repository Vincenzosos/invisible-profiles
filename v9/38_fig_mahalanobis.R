# ==============================================================================
# FIG 3.2 — Mahalanobis distance distribution (faithful to deployed screening)
# Thesis: "Beyond the Monolith"
#
# Reproduces EXACTLY the deployed outlier screening of 02/04_listwise_outliers*.R:
#   - post-listwise sample (complete.cases on all 31 vars): 2,431 IT / 1,831 SE
#   - rank-transform the 20 non-binary vars, z-standardise all 31
#   - Mahalanobis on ALL 31 standardised variables (no zero-variance drop)
#   - cutoff = qchisq(0.999, df = 31) = 61.10 for BOTH countries
#   - respondents beyond cutoff excluded: expect 53 IT / 44 SE
# (At the post-listwise stage ac035d4/d7 still have non-zero variance in Italy;
#  they become zero-variance only after Mahalanobis removes the few rare joiners.)
#
# OUTPUT: Invisible_Profiles_LaTeX_Overleaf/figures/03_data_methods/fig_mahalanobis_distribution_v2.png
#   (original fig_mahalanobis_distribution.png preserved for rollback)
# ==============================================================================
suppressPackageStartupMessages({library(dplyr); library(tidyr); library(ggplot2)})
setwd("/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH")

health <- c("sphus","chronic","adl","iadl","mobility","eurod","bmi","phinact")
econ   <- c("log_thinc","log_hnetw","ypen1","home_own","fdistress")
digital<- c("internet","ac035d1","ac035d5","ac035d8","sp002_","sp008_","sn_size_w9","social_integration","ac035d4","ac035d7")
cog    <- c("fluency","memory","orienti"); subj <- c("loneliness","casp","hope_future","interest","expect_alive")
all31  <- c(health,econ,digital,cog,subj)
binary <- c("phinact","home_own","internet","ac035d1","ac035d5","ac035d8","sp002_","sp008_","ac035d4","ac035d7","hope_future")
nonbin <- setdiff(all31, binary)

country_colors <- c(Italy = "#3B528B", Sweden = "#7FB3DB")

# Reconstruct the post-listwise standardised sample and Mahalanobis exactly as 02/04
deployed_mahal <- function(assembled) {
  sc <- assembled[complete.cases(assembled[, all31]), ]
  rk <- sc; for (v in nonbin) rk[[v]] <- rank(rk[[v]], ties.method = "average")
  st <- rk; for (v in all31)  st[[v]] <- as.numeric(scale(st[[v]]))
  X  <- as.matrix(st[, all31])                     # ALL 31, no zero-var drop
  d  <- mahalanobis(X, colMeans(X), cov(X))        # df = 31
  list(n = nrow(st), d = d)
}

it <- deployed_mahal(readRDS("v9/outputs/step1_italy_assembled.rds"))
se <- deployed_mahal(readRDS("v9/outputs/step3_sweden_assembled.rds"))

CUT <- qchisq(0.999, df = length(all31))            # = 61.10, both countries
cat(sprintf("Cutoff chi-squared(df=%d, p=0.001) = %.2f  (both countries)\n", length(all31), CUT))
cat(sprintf("Italy : post-listwise n=%d ; beyond cutoff = %d (%.1f%%)\n", it$n, sum(it$d > CUT), 100*mean(it$d > CUT)))
cat(sprintf("Sweden: post-listwise n=%d ; beyond cutoff = %d (%.1f%%)\n", se$n, sum(se$d > CUT), 100*mean(se$d > CUT)))

mah_all <- bind_rows(
  tibble(country = "Italy",  d = it$d),
  tibble(country = "Sweden", d = se$d)
) %>% mutate(country = factor(country, levels = c("Italy","Sweden")))

lab <- tibble(country = factor(c("Italy","Sweden"), levels = c("Italy","Sweden")),
              cutoff = CUT)

p_mah <- ggplot(mah_all, aes(d, fill = country, color = country)) +
  geom_density(alpha = 0.35, linewidth = 0.6) +
  geom_vline(xintercept = CUT, linetype = "dashed", color = "grey30", linewidth = 0.7) +
  geom_text(data = lab, aes(x = cutoff, y = 0.005,
            label = sprintf("χ²(31) = %.1f", cutoff)),
            inherit.aes = FALSE, angle = 90, vjust = -0.5, hjust = 0, size = 3.4,
            color = "grey30", fontface = "italic", family = "Times") +
  scale_fill_manual(values = country_colors) +
  scale_color_manual(values = country_colors) +
  facet_wrap(~ country, scales = "free_y", ncol = 2) +
  coord_cartesian(xlim = c(0, 90)) +
  labs(x = "Mahalanobis distance", y = "Density", fill = NULL, color = NULL) +
  theme_minimal(base_family = "Times", base_size = 12) +
  theme(legend.position = "top",
        plot.caption = element_text(color = "gray45", size = 9, hjust = 0, margin = margin(t = 8)),
        strip.text = element_text(face = "bold", size = 11),
        strip.background = element_rect(fill = "gray95", color = NA),
        panel.grid.minor = element_blank())

out <- "Invisible_Profiles_LaTeX_Overleaf/figures/03_data_methods/fig_mahalanobis_distribution_v2.png"
ggsave(out, p_mah, width = 12, height = 5.5, dpi = 300, bg = "white")
cat("Saved:", out, "\n")
