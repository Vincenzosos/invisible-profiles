# ==============================================================================
# STEP 16: HANDS-ON PCA COURSE-CANON FIGURES
# Thesis: "Invisible Profiles" — Bocconi MSc DSBA (course 20570, Prof. Trentini)
#
# Adds five figures that replicate the diagnostic plots from the Piccareta &
# Trentini "Hands-on on Principal Components Analysis" (March 2025), which
# are missing from Step 12 and Step 13:
#
#   Fig 52  PC1-PC2 Italy colored by cos squared (quality of representation)
#   Fig 53  PC1-PC2 Sweden colored by cos squared (quality of representation)
#   Fig 54  Cumulative proportion of explained variance per variable, Italy
#   Fig 55  Cumulative proportion of explained variance per variable, Sweden
#   Fig 56  PC1-PC2 pooled Italy + Sweden, colored by country (cross-country map)
#
# The three blocks answer the three canonical questions from the hands-on:
#   Q1 global performance of the PCs    -> already covered by figs 02, 03, 40
#   Q2 variable- and case-specific performance -> FIGS 52-55 (this script)
#   Q3 PC vs a-priori characteristics   -> FIG 56 (this script)
#
# INPUT : v9/outputs/step2_italy_std.rds,  v9/outputs/step4_sweden_std.rds
# OUTPUT: v9/figures/fig_52_*.png ... fig_56_*.png
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(ggrepel)
  library(scales)
  library(patchwork)
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
fig_dir   <- file.path(data_path, "v9", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Human-readable variable labels (shared with Step 12/13/14/15/17/18).
source(file.path(data_path, "v9", "var_labels.R"))
# Chapter-subfolder routing for save_fig().
source(file.path(data_path, "v9", "fig_paths.R"))

cat("============================================================\n")
cat("STEP 16: HANDS-ON PCA COURSE-CANON FIGURES\n")
cat("============================================================\n\n")


# ##############################################################################
# GLOBAL THEME & PALETTE (identical to Step 12 / Step 13)
# ##############################################################################

theme_thesis <- function(base_size = 11) {
  theme_classic(base_size = base_size) +
    theme(
      text          = element_text(family = "sans"),
      plot.title    = element_text(face = "bold", size = base_size + 1, hjust = 0),
      plot.subtitle = element_text(size = base_size - 1, colour = "grey30"),
      axis.title    = element_text(size = base_size),
      axis.text     = element_text(size = base_size - 1),
      legend.title  = element_text(size = base_size - 1, face = "bold"),
      legend.text   = element_text(size = base_size - 1),
      strip.text    = element_text(face = "bold", size = base_size),
      strip.background = element_rect(fill = "grey92", colour = NA),
      panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.3),
      plot.caption  = element_text(size = base_size - 2, colour = "grey40", hjust = 0)
    )
}

col_italy    <- "#0F4C81"
col_sweden   <- "#8DB9CA"
col_accent   <- "#E07A5F"
col_neutral  <- "grey40"

# Hands-on course palette for cos squared (red = poorly represented, black = well)
cos2_palette <- c("#D73027", "#984EA3", "#1F78B4", "black")

save_fig <- function(p, name, w = 7, h = 5, also_pdf = FALSE) {
  out_dir <- ensure_fig_dir(fig_dir, name)
  base    <- file.path(out_dir, name)
  ggsave(paste0(base, ".png"), p, width = w, height = h, dpi = 300, bg = "white")
  if (also_pdf) ggsave(paste0(base, ".pdf"), p, width = w, height = h, bg = "white")
  cat(sprintf("    \u2713 %s  (%.1fx%.1f in)  -> %s/\n",
              name, w, h, basename(out_dir)))
}


# ##############################################################################
# LOAD DATA AND DEFINE ACTIVE VARIABLES
# ##############################################################################

cat("--- Loading standardized datasets ---\n")
italy_std  <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_std.rds"))
sweden_std <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_std.rds"))
cat(sprintf("  Italy:  %d rows\n", nrow(italy_std)))
cat(sprintf("  Sweden: %d rows\n\n", nrow(sweden_std)))

health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")
all_31       <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

italy_active  <- setdiff(all_31, c("ac035d4", "ac035d7"))   # 29 vars
sweden_active <- all_31                                      # 31 vars

X_italy  <- as.matrix(italy_std[,  italy_active])
X_sweden <- as.matrix(sweden_std[, sweden_active])


# ##############################################################################
# HELPER: GLOBAL PCA + COS SQUARED (following hands-on Section 4.2 logic)
# ##############################################################################

compute_pca_with_cos2 <- function(X) {
  # X is already standardized (mean 0, sd 1 per variable)
  # prcomp with center=FALSE, scale.=FALSE to preserve the standardization
  pca <- prcomp(X, center = FALSE, scale. = FALSE)

  scores    <- pca$x                          # n x p
  sdev      <- pca$sdev
  eigval    <- sdev^2
  prop_var  <- eigval / sum(eigval)

  # Squared cosines: quality of representation of case i on PC m
  # cos2_{i,m} = score_{i,m}^2 / sum_k X_{i,k}^2
  # The row sum of X^2 is the squared distance of case i from the origin
  dist_sq   <- rowSums(X^2)
  cos2      <- sweep(scores^2, 1, dist_sq, "/")
  colnames(cos2) <- paste0("cos2_", seq_len(ncol(cos2)))

  # Cumulative cos squared on the first k PCs
  cos2_cum  <- t(apply(cos2, 1, cumsum))
  colnames(cos2_cum) <- paste0("cos2_1to", seq_len(ncol(cos2_cum)))

  # Correlations between active variables and PCs = loadings for std data
  corr_var_pc <- cor(X, scores)

  # Cumulative proportion of explained variance per variable
  # (squared correlations cumulated across PCs)
  cum_prop_var <- t(apply(corr_var_pc^2, 1, cumsum))
  colnames(cum_prop_var) <- paste0("prop_1to", seq_len(ncol(cum_prop_var)))

  list(
    pca           = pca,
    scores        = scores,
    prop_var      = prop_var,
    cos2          = cos2,
    cos2_cum      = cos2_cum,
    corr_var_pc   = corr_var_pc,
    cum_prop_var  = cum_prop_var
  )
}

cat("--- Computing global PCA + cos squared for Italy ---\n")
pca_it <- compute_pca_with_cos2(X_italy)
cat(sprintf("  PC1 %.1f%%  PC2 %.1f%%  PC3 %.1f%%  PC4 %.1f%%\n",
            100 * pca_it$prop_var[1], 100 * pca_it$prop_var[2],
            100 * pca_it$prop_var[3], 100 * pca_it$prop_var[4]))

cat("--- Computing global PCA + cos squared for Sweden ---\n")
pca_se <- compute_pca_with_cos2(X_sweden)
cat(sprintf("  PC1 %.1f%%  PC2 %.1f%%  PC3 %.1f%%  PC4 %.1f%%\n\n",
            100 * pca_se$prop_var[1], 100 * pca_se$prop_var[2],
            100 * pca_se$prop_var[3], 100 * pca_se$prop_var[4]))


# ##############################################################################
# FIG 52 & 53 — PC1-PC2 SCATTER COLORED BY COS SQUARED
# Replicates hands-on Section 2.1 (pages 7-8): quality-of-representation map
# ##############################################################################

plot_cos2_scatter <- function(pca_obj, country_col, country_name, fig_num) {
  scores   <- pca_obj$scores
  prop_var <- pca_obj$prop_var
  cos2_1   <- pca_obj$cos2[, 1]
  cos2_12  <- pca_obj$cos2_cum[, 2]

  df <- data.frame(
    PC1     = scores[, 1],
    PC2     = scores[, 2],
    cos2_1  = cos2_1,
    cos2_12 = cos2_12
  )

  base_scatter <- function(df_in, fill_var, lab_title) {
    ggplot(df_in, aes(x = PC1, y = PC2)) +
      geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
      geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.3) +
      geom_point(aes(fill = .data[[fill_var]]), shape = 21, colour = "white",
                 size = 1.8, stroke = 0.2, alpha = 0.9) +
      scale_fill_gradientn(colours = cos2_palette, limits = c(0, 1),
                           name = expression(cos^2)) +
      labs(title = lab_title,
           x = sprintf("PC1 (%.1f%%)", 100 * prop_var[1]),
           y = sprintf("PC2 (%.1f%%)", 100 * prop_var[2])) +
      theme_thesis() +
      theme(legend.position = "right")
  }

  p_left  <- base_scatter(df, "cos2_1",
                          expression("Quality on PC1 (cos"^2~"of PC1)"))
  p_right <- base_scatter(df, "cos2_12",
                          expression("Quality on the PC1-PC2 plane (cos"^2~"cumulated)"))

  (p_left | p_right) +
    plot_annotation(
      title = sprintf("Figure %d. Representation quality on the first principal plane, %s",
                      fig_num, country_name),
      subtitle = "Each respondent colored by the share of squared distance from the origin recovered by PC1 (left) and by the PC1-PC2 plane (right)",
      caption  = "High cos^2 (black) = case well summarised by the component(s); low cos^2 (red) = case near the origin or poorly represented.",
      theme = theme_thesis()
    )
}

cat("--- FIG 52: PC cos^2 scatter Italy ---\n")
p52 <- plot_cos2_scatter(pca_it, col_italy, "Italy", 52)
save_fig(p52, "fig_52_pc_cos2_italy", w = 12, h = 5.5)

cat("--- FIG 53: PC cos^2 scatter Sweden ---\n")
p53 <- plot_cos2_scatter(pca_se, col_sweden, "Sweden", 53)
save_fig(p53, "fig_53_pc_cos2_sweden", w = 12, h = 5.5)


# ##############################################################################
# FIG 54 & 55 — CUMULATIVE PROPORTION OF EXPLAINED VARIANCE PER VARIABLE
# Replicates hands-on Section 2.1 top heatmap (page 6)
# ##############################################################################

plot_cum_prop_per_var <- function(pca_obj, country_col, country_name, fig_num, n_pcs = 7) {
  mat <- pca_obj$cum_prop_var[, seq_len(n_pcs), drop = FALSE]
  colnames(mat) <- paste0("1:", seq_len(n_pcs))

  df <- as.data.frame(mat) %>%
    tibble::rownames_to_column("variable") %>%
    pivot_longer(-variable, names_to = "pc_range", values_to = "cum_prop") %>%
    mutate(
      pc_range = factor(pc_range, levels = paste0("1:", seq_len(n_pcs))),
      variable = factor(variable, levels = rev(rownames(mat))),
      label_txt = sprintf("%.2f", cum_prop)
    )

  y_vars_order <- rownames(mat)
  ggplot(df, aes(x = pc_range, y = variable, fill = cum_prop)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    geom_text(aes(label = label_txt, colour = cum_prop > 0.5),
              size = 2.6, show.legend = FALSE) +
    scale_fill_gradient(low = "#F7FBFF", high = country_col, limits = c(0, 1),
                        name = "Cum. prop.") +
    scale_colour_manual(values = c(`FALSE` = "grey20", `TRUE` = "white")) +
    scale_y_discrete(labels = setNames(relabel(y_vars_order, style = "scale"),
                                       y_vars_order)) +
    labs(title = sprintf("Figure %d. Cumulative proportion of explained variance per variable, %s",
                         fig_num, country_name),
         subtitle = sprintf("Columns: first k PCs (k = 1..%d); values: squared correlations cumulated per active variable", n_pcs),
         x = "First k PCs included",
         y = NULL,
         caption = "A value of 1.00 means the variance of the variable is fully recovered by the first k PCs. Variables stabilising early are well summarised; late-stabilising variables describe peculiar deviations.") +
    theme_thesis() +
    theme(panel.grid = element_blank(),
          axis.text.y = element_text(size = 8),
          axis.text.x = element_text(size = 10))
}

cat("--- FIG 54: Cum-prop per variable Italy ---\n")
p54 <- plot_cum_prop_per_var(pca_it, col_italy, "Italy", 54, n_pcs = 7)
save_fig(p54, "fig_54_cumprop_pervar_italy", w = 7.5, h = 9)

cat("--- FIG 55: Cum-prop per variable Sweden ---\n")
p55 <- plot_cum_prop_per_var(pca_se, col_sweden, "Sweden", 55, n_pcs = 7)
save_fig(p55, "fig_55_cumprop_pervar_sweden", w = 7.5, h = 9.5)


# ##############################################################################
# FIG 56 — POOLED PC1-PC2, ITALY + SWEDEN, COLORED BY COUNTRY
# Replicates hands-on Section 3.2 (PC map colored by a-priori characteristic)
# ##############################################################################
#
# Rationale: the hands-on colors PC scores by external country attributes
# (Region, Income, GDP, Political Regime) to validate the interpretation of
# the components. In our cross-country SHARE design the most natural
# "a-priori characteristic" is the country itself. A pooled PCA on the
# intersection of active variables reveals whether PC1 separates by country
# (indicating welfare-regime divergence) or whether Italian and Swedish
# respondents overlap in the component space.

cat("--- FIG 56: Pooled PC scatter by country ---\n")

# Intersect active variables (Italy active excludes ac035d4 and ac035d7)
common_vars <- intersect(italy_active, sweden_active)
cat(sprintf("  Common active variables: %d\n", length(common_vars)))

# Pool: each dataset already standardized within country; we restandardize
# on the pooled data to put both countries on the same axes
X_pooled <- rbind(
  as.matrix(italy_std[,  common_vars]),
  as.matrix(sweden_std[, common_vars])
)
country_vec <- factor(
  c(rep("Italy",  nrow(italy_std)),
    rep("Sweden", nrow(sweden_std))),
  levels = c("Italy", "Sweden")
)

# Re-standardize on pooled sample
X_pooled_std <- scale(X_pooled, center = TRUE, scale = TRUE)
pca_pool     <- prcomp(X_pooled_std, center = FALSE, scale. = FALSE)

pooled_scores <- pca_pool$x[, 1:2]
pooled_prop   <- (pca_pool$sdev^2 / sum(pca_pool$sdev^2))[1:2]

df_pool <- data.frame(
  PC1     = pooled_scores[, 1],
  PC2     = pooled_scores[, 2],
  country = country_vec
)

# Country centroids
cent_pool <- df_pool %>%
  group_by(country) %>%
  summarise(PC1 = mean(PC1), PC2 = mean(PC2), .groups = "drop")

p56 <- ggplot(df_pool, aes(x = PC1, y = PC2, colour = country)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_point(alpha = 0.35, size = 1.2) +
  geom_point(data = cent_pool, aes(x = PC1, y = PC2, fill = country),
             shape = 23, colour = "black", size = 5, stroke = 0.6) +
  scale_colour_manual(values = c(Italy = col_italy, Sweden = col_sweden), name = "Country") +
  scale_fill_manual(values   = c(Italy = col_italy, Sweden = col_sweden), guide = "none") +
  labs(title = "Figure 56. Pooled first principal plane, Italy and Sweden",
       subtitle = sprintf("PCA on %d common active variables after joint standardisation; points = respondents, diamonds = country centroids",
                          length(common_vars)),
       x = sprintf("PC1 (%.1f%%)", 100 * pooled_prop[1]),
       y = sprintf("PC2 (%.1f%%)", 100 * pooled_prop[2]),
       caption = "Separation along PC1 reflects the dominant cross-country gradient in the analytical variable set; vertical overlap signals shared variance within each country.") +
  theme_thesis() +
  theme(legend.position = "top")

save_fig(p56, "fig_56_pc_pooled_by_country", w = 9, h = 6)


# ##############################################################################
# SUMMARY
# ##############################################################################

cat("\n============================================================\n")
cat("STEP 16 COMPLETE — 5 course-canon PCA figures generated\n")
cat("============================================================\n")
cat("  fig_52_pc_cos2_italy.png        PC1-PC2 IT colored by cos^2\n")
cat("  fig_53_pc_cos2_sweden.png       PC1-PC2 SE colored by cos^2\n")
cat("  fig_54_cumprop_pervar_italy.png cum prop expl var per variable IT\n")
cat("  fig_55_cumprop_pervar_sweden.png cum prop expl var per variable SE\n")
cat("  fig_56_pc_pooled_by_country.png pooled PC1-PC2 IT+SE by country\n\n")
cat("Saved to:", fig_dir, "\n")
