# ==============================================================================
# STEP 17: HANDS-ON FA COURSE-CANON FIGURES
# Thesis: "Invisible Profiles" — Bocconi MSc DSBA (course 20570, Prof. Trentini)
#
# Adds seven figures that replicate the diagnostic plots from the Piccareta &
# Trentini "Hands-on on Factor Analysis" (April 2025), which are missing
# from Step 12, Step 13 and Step 16:
#
#   Fig 57  Prior communalities (SMC + MaxC), Italy and Sweden side-by-side
#   Fig 58  Communalities evolution 1F-7F, Italy
#   Fig 59  Communalities evolution 1F-7F, Sweden
#   Fig 60  Critical residuals diagnostic, Italy (6-factor PA varimax)
#   Fig 61  Critical residuals diagnostic, Sweden (6-factor PA varimax)
#   Fig 62  Pooled factor scatter PA1-PA2, Italy + Sweden, colored by country
#   Fig 63  Factor scatter PA1-PA2, Italy, colored by age band and gender
#
# The script addresses the hands-on canonical outputs:
#   Q1 variables-specific performance (prior and final communalities)   -> 57-59
#   Q2 choice of number of factors (residual structure)                 -> 60-61
#   Q3 interpretation via a-priori characteristics (country, age, sex)  -> 62-63
#
# INPUT : v9/outputs/step2_italy_std.rds,     v9/outputs/step4_sweden_std.rds
#         v9/outputs/step5_italy_fa_results.rds, v9/outputs/step6_sweden_fa_results.rds
#         v9/outputs/step7_italy_with_clusters.rds (for age / gender)
# OUTPUT: v9/figures/fig_57_*.png ... fig_63_*.png
# ==============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(patchwork)
  if (!requireNamespace("psych", quietly = TRUE)) install.packages("psych", quiet = TRUE)
  library(psych)
  if (!requireNamespace("corpcor", quietly = TRUE)) install.packages("corpcor", quiet = TRUE)
  library(corpcor)     # for pseudoinverse if cor matrix is singular
  library(tibble)
})

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
fig_dir   <- file.path(data_path, "v9", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Human-readable variable labels (shared with Step 12/13/14/15/16/18).
source(file.path(data_path, "v9", "var_labels.R"))
# Chapter-subfolder routing for save_fig().
source(file.path(data_path, "v9", "fig_paths.R"))

cat("============================================================\n")
cat("STEP 17: HANDS-ON FA COURSE-CANON FIGURES\n")
cat("============================================================\n\n")


# ##############################################################################
# GLOBAL THEME & PALETTE (identical to Step 12 / 13 / 16)
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

col_italy   <- "#0F4C81"
col_sweden  <- "#8DB9CA"
col_accent  <- "#E07A5F"
col_neutral <- "grey40"

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

cat("--- Loading pipeline outputs ---\n")
italy_std    <- readRDS(file.path(data_path, "v9", "outputs", "step2_italy_std.rds"))
sweden_std   <- readRDS(file.path(data_path, "v9", "outputs", "step4_sweden_std.rds"))
fa_italy     <- readRDS(file.path(data_path, "v9", "outputs", "step5_italy_fa_results.rds"))
fa_sweden    <- readRDS(file.path(data_path, "v9", "outputs", "step6_sweden_fa_results.rds"))
italy_clust  <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
cat(sprintf("  Italy:  %d rows, %d active vars\n", nrow(italy_std),  length(fa_italy$active_vars)))
cat(sprintf("  Sweden: %d rows, %d active vars\n\n", nrow(sweden_std), length(fa_sweden$active_vars)))

italy_active  <- fa_italy$active_vars
sweden_active <- fa_sweden$active_vars

X_italy  <- as.matrix(italy_std[,  italy_active])
X_sweden <- as.matrix(sweden_std[, sweden_active])

R_italy  <- cor(X_italy)
R_sweden <- cor(X_sweden)


# ##############################################################################
# HELPER: PRIOR COMMUNALITIES (SMC + MaxC) FROM CORRELATION MATRIX
# ##############################################################################

prior_communalities <- function(R) {
  # SMC_i = 1 - 1/R^{-1}[i,i]  (squared multiple correlation of var i on others)
  # Use pseudoinverse for numerical stability
  R_inv <- tryCatch(solve(R), error = function(e) corpcor::pseudoinverse(R))
  smc <- 1 - 1 / diag(R_inv)
  smc <- pmin(pmax(smc, 0), 1)   # bound to [0,1] against numerical slips

  # Max absolute off-diagonal correlation for each variable
  R_off <- R
  diag(R_off) <- 0
  maxc <- apply(abs(R_off), 1, max)

  data.frame(variable = rownames(R), SMC = smc, MaxC = maxc,
             row.names = NULL, stringsAsFactors = FALSE)
}


# ##############################################################################
# FIG 57 — PRIOR COMMUNALITIES (SMC + MaxC), ITALY AND SWEDEN
# Replicates hands-on page 5 top heatmap
# ##############################################################################

cat("--- FIG 57: Prior communalities (SMC + MaxC) ---\n")

prior_it <- prior_communalities(R_italy)  %>% mutate(country = "Italy")
prior_se <- prior_communalities(R_sweden) %>% mutate(country = "Sweden")

# Align on union of active variables for visual comparability
all_vars <- union(italy_active, sweden_active)

prior_long <- bind_rows(prior_it, prior_se) %>%
  pivot_longer(c(SMC, MaxC), names_to = "metric", values_to = "value") %>%
  mutate(
    country  = factor(country, levels = c("Italy", "Sweden")),
    metric   = factor(metric,  levels = c("SMC", "MaxC")),
    variable = factor(variable, levels = rev(all_vars)),
    col_key  = paste(country, metric, sep = " \u2014 "),
    col_key  = factor(col_key,
                      levels = c("Italy \u2014 SMC",  "Italy \u2014 MaxC",
                                 "Sweden \u2014 SMC", "Sweden \u2014 MaxC"))
  )

p57 <- ggplot(prior_long, aes(x = col_key, y = variable, fill = value)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = ifelse(is.na(value), "", sprintf("%.2f", value)),
                colour = value > 0.5),
            size = 2.7, show.legend = FALSE) +
  scale_fill_gradient(low = "#FBE9E7", high = "#5C6BC0", limits = c(0, 1),
                      na.value = "grey90", name = "Prior h\u00b2") +
  scale_colour_manual(values = c(`FALSE` = "grey20", `TRUE` = "white")) +
  scale_y_discrete(labels = setNames(relabel(all_vars, style = "scale"), all_vars)) +
  labs(title = "Figure 57. Prior communality estimates, Italy and Sweden",
       subtitle = "SMC = squared multiple correlation; MaxC = maximal absolute off-diagonal correlation",
       x = NULL, y = NULL,
       caption = "Variables with low SMC and low MaxC are weakly connected to the rest of the set; they are unlikely to load strongly on any common factor.") +
  theme_thesis() +
  theme(panel.grid  = element_blank(),
        axis.text.y = element_text(size = 8),
        axis.text.x = element_text(size = 9, angle = 30, hjust = 1))

save_fig(p57, "fig_57_prior_communalities", w = 8, h = 9.5)


# ##############################################################################
# HELPER: COMMUNALITIES EVOLUTION ACROSS 1F-7F
# ##############################################################################

communalities_evolution <- function(X, k_max = 7, rotate = "varimax", fm = "pa") {
  comm_mat <- matrix(NA, nrow = ncol(X), ncol = k_max,
                     dimnames = list(colnames(X), paste0("Comm.", seq_len(k_max), "F")))
  for (k in seq_len(k_max)) {
    fit <- tryCatch(
      suppressWarnings(psych::fa(X, nfactors = k,
                                 rotate = ifelse(k == 1, "none", rotate),
                                 fm = fm, warnings = FALSE)),
      error = function(e) NULL
    )
    if (!is.null(fit)) comm_mat[, k] <- fit$communality[colnames(X)]
  }
  comm_mat
}


# ##############################################################################
# FIG 58 & 59 — COMMUNALITIES EVOLUTION (vars x 1F-7F)
# Replicates hands-on page 7 Communalities-PC and Communalities-PF heatmaps
# ##############################################################################

plot_comm_evolution <- function(comm_mat, prior_df, country_col, country_name, fig_num) {
  # Attach SMC and MaxC columns for context (the hands-on places them alongside)
  tab <- as.data.frame(comm_mat) %>%
    tibble::rownames_to_column("variable") %>%
    left_join(prior_df, by = "variable") %>%
    pivot_longer(-variable, names_to = "column", values_to = "value") %>%
    mutate(
      column = factor(column,
                      levels = c(paste0("Comm.", 1:7, "F"), "SMC", "MaxC"),
                      labels = c(paste0("1F"),  paste0("2F"), paste0("3F"),
                                 paste0("4F"), paste0("5F"),  paste0("6F"),
                                 paste0("7F"), "SMC", "MaxC")),
      variable = factor(variable, levels = rev(rownames(comm_mat))),
      label_txt = ifelse(is.na(value), "", sprintf("%.2f", value))
    )

  y_vars_order <- rownames(comm_mat)
  ggplot(tab, aes(x = column, y = variable, fill = value)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    geom_text(aes(label = label_txt, colour = value > 0.5),
              size = 2.6, show.legend = FALSE) +
    scale_fill_gradient(low = "#F7FBFF", high = country_col, limits = c(0, 1),
                        na.value = "grey90", name = "h\u00b2") +
    scale_colour_manual(values = c(`FALSE` = "grey20", `TRUE` = "white")) +
    scale_y_discrete(labels = setNames(relabel(y_vars_order, style = "scale"),
                                       y_vars_order)) +
    labs(title = sprintf("Figure %d. Communalities evolution across factor solutions, %s",
                         fig_num, country_name),
         subtitle = "Columns 1F-7F: communalities for the k-factor varimax-rotated PA solution; SMC and MaxC: prior estimates",
         x = "Factor solution",
         y = NULL,
         caption = "Variables whose h\u00b2 stabilises early are well summarised by few factors; variables whose h\u00b2 keeps rising suggest a dedicated factor is being carved out.") +
    theme_thesis() +
    theme(panel.grid  = element_blank(),
          axis.text.y = element_text(size = 8),
          axis.text.x = element_text(size = 9))
}

cat("--- FIG 58: Communalities evolution Italy ---\n")
comm_it <- communalities_evolution(X_italy,  k_max = 7)
p58 <- plot_comm_evolution(comm_it,  prior_it %>% select(-country),
                            col_italy,  "Italy",  58)
save_fig(p58, "fig_58_communalities_evolution_italy", w = 9, h = 9)

cat("--- FIG 59: Communalities evolution Sweden ---\n")
comm_se <- communalities_evolution(X_sweden, k_max = 7)
p59 <- plot_comm_evolution(comm_se, prior_se %>% select(-country),
                            col_sweden, "Sweden", 59)
save_fig(p59, "fig_59_communalities_evolution_sweden", w = 9, h = 9.5)


# ##############################################################################
# HELPER: CRITICAL RESIDUALS FROM A FITTED FA OBJECT
# ##############################################################################

critical_residuals <- function(fa_obj, R, top_n = 15) {
  # psych::fa stores residual = observed - reproduced (off-diagonal)
  res_mat <- fa_obj$residual
  # Upper triangle only, exclude diagonal
  pairs_idx <- which(upper.tri(res_mat), arr.ind = TRUE)
  df <- data.frame(
    Var1   = rownames(res_mat)[pairs_idx[, 1]],
    Var2   = colnames(res_mat)[pairs_idx[, 2]],
    Obs    = R[pairs_idx],
    Res    = res_mat[pairs_idx],
    stringsAsFactors = FALSE
  )
  df$Pred   <- df$Obs - df$Res
  df$AbsRes <- abs(df$Res)
  df <- df[order(-df$AbsRes), ]
  head(df, top_n)
}


# ##############################################################################
# FIG 60 & 61 — CRITICAL RESIDUALS DIAGNOSTIC
# Replicates hands-on page 11 critical residuals table
# ##############################################################################

plot_critical_residuals <- function(crit_df, country_col, country_name, fig_num) {
  df <- crit_df %>%
    mutate(pair = paste(relabel(Var1), "-", relabel(Var2)),
           pair = factor(pair, levels = rev(pair)),
           sign_res = ifelse(Res > 0, "Under-estimated", "Over-estimated"),
           label_txt = sprintf("Obs %.2f | Pred %.2f | Res %+.2f", Obs, Pred, Res))

  ggplot(df, aes(x = AbsRes, y = pair, fill = sign_res)) +
    geom_col(width = 0.7, colour = "white", linewidth = 0.3) +
    geom_text(aes(label = label_txt), hjust = -0.05, size = 2.7, colour = "grey20") +
    scale_fill_manual(values = c("Under-estimated" = country_col,
                                  "Over-estimated"  = col_accent),
                      name = NULL) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.55))) +
    labs(title = sprintf("Figure %d. Critical residuals of the 6-factor FA solution, %s",
                          fig_num, country_name),
         subtitle = "Top 15 variable pairs ranked by absolute residual correlation (observed minus reproduced by the model)",
         x = expression("|residual|"),
         y = NULL,
         caption = "Obs = observed correlation; Pred = correlation reproduced by the factor model; Res = Obs - Pred. Large positive residuals flag pairs the model under-explains; large negative residuals flag pairs whose correlation is inflated by the factor structure.") +
    theme_thesis() +
    theme(panel.grid.major.y = element_blank(),
          legend.position = "top",
          axis.text.y = element_text(size = 8))
}

cat("--- FIG 60: Critical residuals Italy ---\n")
crit_it <- critical_residuals(fa_italy$fa_model,  R_italy,  top_n = 15)
p60 <- plot_critical_residuals(crit_it, col_italy,  "Italy",  60)
save_fig(p60, "fig_60_critical_residuals_italy", w = 11, h = 6)

cat("--- FIG 61: Critical residuals Sweden ---\n")
crit_se <- critical_residuals(fa_sweden$fa_model, R_sweden, top_n = 15)
p61 <- plot_critical_residuals(crit_se, col_sweden, "Sweden", 61)
save_fig(p61, "fig_61_critical_residuals_sweden", w = 11, h = 6)


# ##############################################################################
# FIG 62 — POOLED FA SCATTER PA1-PA2, ITALY + SWEDEN, COLORED BY COUNTRY
# Replicates hands-on page 15 (factor scatter by region) adapted to SHARE design
# ##############################################################################

cat("--- FIG 62: Pooled FA scatter, country ---\n")

# Pool on intersection of active variables (Italy excludes ac035d4, ac035d7)
common_vars <- intersect(italy_active, sweden_active)
cat(sprintf("  Common active variables for pooled FA: %d\n", length(common_vars)))

X_pool <- rbind(
  as.matrix(italy_std[,  common_vars]),
  as.matrix(sweden_std[, common_vars])
)
country_vec <- factor(
  c(rep("Italy",  nrow(italy_std)), rep("Sweden", nrow(sweden_std))),
  levels = c("Italy", "Sweden")
)

# Re-standardize on the pooled sample for FA (mean 0, sd 1 per variable in pool)
X_pool_std <- scale(X_pool, center = TRUE, scale = TRUE)

set.seed(42)
fa_pool <- suppressWarnings(
  psych::fa(X_pool_std, nfactors = 6, rotate = "varimax", fm = "pa",
            scores = "regression", warnings = FALSE)
)

scores_pool <- as.data.frame(fa_pool$scores)
colnames(scores_pool) <- paste0("PA", 1:6)
scores_pool$country   <- country_vec

cent_pool <- scores_pool %>%
  group_by(country) %>%
  summarise(PA1 = mean(PA1), PA2 = mean(PA2), .groups = "drop")

p62 <- ggplot(scores_pool, aes(x = PA1, y = PA2, colour = country)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_point(alpha = 0.30, size = 1.1) +
  geom_point(data = cent_pool, aes(x = PA1, y = PA2, fill = country),
             shape = 23, colour = "black", size = 5, stroke = 0.6) +
  scale_colour_manual(values = c(Italy = col_italy, Sweden = col_sweden), name = "Country") +
  scale_fill_manual(values   = c(Italy = col_italy, Sweden = col_sweden), guide = "none") +
  labs(title = "Figure 62. Pooled first factorial plane, Italy and Sweden",
       subtitle = sprintf("Six-factor PA varimax FA on %d common active variables after joint standardisation; points = respondents, diamonds = country centroids",
                          length(common_vars)),
       x = "PA1 (first rotated factor)",
       y = "PA2 (second rotated factor)",
       caption = "Factor orientation is arbitrary up to sign. Separation along PA1 reflects the dominant cross-country axis of variation in the analytical variable set.") +
  theme_thesis() +
  theme(legend.position = "top")

save_fig(p62, "fig_62_fa_pooled_by_country", w = 9, h = 6)


# ##############################################################################
# FIG 63 — FA SCATTER PA1-PA2 ITALY, COLORED BY AGE BAND AND GENDER
# Replicates hands-on Q3 (factor map colored by a-priori characteristic)
# ##############################################################################

cat("--- FIG 63: FA scatter Italy by age and gender ---\n")

scores_it <- as.data.frame(fa_italy$factor_scores)
colnames(scores_it) <- paste0("PA", 1:ncol(scores_it))

# Pull age and gender from the clustered dataset (same 2378 respondents)
demo_it <- italy_clust
if ("age" %in% names(demo_it))    demo_it$age    <- as.numeric(as.vector(demo_it$age))
if ("gender" %in% names(demo_it)) demo_it$gender <- as.numeric(as.vector(demo_it$gender))

demo_it$age_band <- cut(demo_it$age, breaks = c(-Inf, 74, 84, Inf),
                        labels = c("65-74", "75-84", "85+"))
demo_it$gender_label <- factor(ifelse(demo_it$gender == 2, "Female", "Male"),
                               levels = c("Female", "Male"))

# Align row counts (italy_std and italy_clust share n = 2,378; pair row-by-row)
stopifnot(nrow(scores_it) == nrow(demo_it))

df_it <- bind_cols(scores_it %>% select(PA1, PA2),
                    demo_it %>% select(age_band, gender_label))

# Panel A: age band
p63a <- ggplot(df_it %>% filter(!is.na(age_band)),
               aes(x = PA1, y = PA2, colour = age_band)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_point(alpha = 0.35, size = 1.1) +
  stat_ellipse(level = 0.6, linewidth = 0.7) +
  scale_colour_manual(values = c("65-74" = "#4575B4",
                                  "75-84" = "#FDAE61",
                                  "85+"    = "#D73027"),
                      name = "Age band") +
  labs(title = "A. By age band", x = "PA1", y = "PA2") +
  theme_thesis() +
  theme(legend.position = "top")

# Panel B: gender
p63b <- ggplot(df_it %>% filter(!is.na(gender_label)),
               aes(x = PA1, y = PA2, colour = gender_label)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.3) +
  geom_point(alpha = 0.35, size = 1.1) +
  stat_ellipse(level = 0.6, linewidth = 0.7) +
  scale_colour_manual(values = c("Female" = "#C2185B", "Male" = "#1976D2"),
                      name = "Gender") +
  labs(title = "B. By gender", x = "PA1", y = "PA2") +
  theme_thesis() +
  theme(legend.position = "top")

p63 <- (p63a | p63b) +
  plot_annotation(
    title = "Figure 63. First factorial plane colored by demographics, Italy",
    subtitle = "Six-factor PA varimax FA scores; ellipses enclose 60% of each group",
    caption  = "Panels share axes. Systematic shifts along PA1 by age or gender indicate that the leading factor partially aligns with demographics.",
    theme    = theme_thesis()
  )

save_fig(p63, "fig_63_fa_scatter_italy_demographics", w = 12, h = 6)


# ##############################################################################
# SUMMARY
# ##############################################################################

cat("\n============================================================\n")
cat("STEP 17 COMPLETE -- 7 course-canon FA figures generated\n")
cat("============================================================\n")
cat("  fig_57_prior_communalities.png               SMC + MaxC, IT + SE\n")
cat("  fig_58_communalities_evolution_italy.png      vars x 1F-7F IT\n")
cat("  fig_59_communalities_evolution_sweden.png     vars x 1F-7F SE\n")
cat("  fig_60_critical_residuals_italy.png           top-15 residual pairs IT\n")
cat("  fig_61_critical_residuals_sweden.png          top-15 residual pairs SE\n")
cat("  fig_62_fa_pooled_by_country.png               pooled PA1-PA2 by country\n")
cat("  fig_63_fa_scatter_italy_demographics.png      PA1-PA2 IT by age + gender\n\n")
cat("Saved to:", fig_dir, "\n")
