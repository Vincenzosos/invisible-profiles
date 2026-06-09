# 30_demographic_regression.R
# -----------------------------------------------------------------------------
# Multinomial logistic regression of cluster membership on standard
# demographic predictors. Reproduces the numbers reported in Cap 4 §4.6.1
# of the thesis (Table 4.3).
#
# Specification:
#   cluster_membership ~ age + female + yedu + single + home_own
#
# Reference category: Moderate Isolated  (matches the focus of §4.7 on
# the Isolation Paradox).
#
# Inputs:
#   outputs/step7_italy_with_clusters.rds   (same file consumed by 11_,
#                                            22_, downstream healthcare
#                                            analyses; rows: 2,378
#                                            Italian SHARE Wave 9
#                                            respondents with cluster
#                                            assignment)
#
# Outputs (printed to stdout; also persisted under outputs/):
#   step30_multinomial_coefs.csv     odds ratios + 95% CI + p per
#                                    (cluster, predictor) cell
#   step30_multinomial_fit.txt       LR chi^2, McFadden, Cox-Snell,
#                                    Nagelkerke pseudo-R^2, n
#
# Run as:
#   cd <repo>/v9 && Rscript 30_demographic_regression.R
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(nnet)        # multinom()
  library(dplyr)
})

out_dir <- "outputs"
stopifnot(dir.exists(out_dir))

df <- readRDS(file.path(out_dir, "step7_italy_with_clusters.rds"))

# Step7 inherits haven_labelled columns from the SHARE import upstream
# (haven::read_dta / read_sav attaches value labels). Strip the labels
# before arithmetic / regression so vec_arith() accepts the operations.
# unclass() removes the haven_labelled attribute and exposes the
# underlying double; some haven/vctrs versions refuse a direct
# as.numeric() cast otherwise.
to_numeric <- function(x) as.numeric(unclass(x))
df <- df %>%
  mutate(
    age      = to_numeric(age),
    yedu     = to_numeric(yedu),
    gender   = to_numeric(gender),
    single   = to_numeric(single),
    home_own = to_numeric(home_own)
  )

# Centre continuous predictors so intercepts are interpretable at the
# median age (75) and the rounded sample mean of years of education (8).
df <- df %>%
  mutate(
    age_c    = age - 75,
    yedu_c   = yedu - 8,
    female   = as.integer(gender == 2),
    single   = as.integer(single),
    home_own = as.integer(home_own)
  )

# Set the reference category. relevel() places the chosen level first;
# multinom() takes the first level as the reference baseline.
df$profile <- factor(
  df$profile,
  levels = c("Moderate Isolated", "Fragile Resigned", "Fragile Depressed",
             "Traditional Social", "Connected Active")
)

predictors <- c("age_c", "female", "yedu_c", "single", "home_own")
analytical <- df %>%
  select(profile, all_of(predictors)) %>%
  na.omit()

cat("Analytical sample (complete cases on predictors): n =", nrow(analytical), "\n")
cat("Cluster distribution:\n")
print(table(analytical$profile))

# Fit multinomial regression
fit <- multinom(
  profile ~ age_c + female + yedu_c + single + home_own,
  data = analytical,
  trace = FALSE,
  maxit = 200
)

# Null model (intercept only) for likelihood-ratio test and pseudo-R^2
fit_null <- multinom(profile ~ 1, data = analytical, trace = FALSE)

ll_full <- as.numeric(logLik(fit))
ll_null <- as.numeric(logLik(fit_null))
n <- nrow(analytical)
df_model <- length(coef(fit)) - length(coef(fit_null))
lr_chi2 <- -2 * (ll_null - ll_full)
lr_p <- pchisq(lr_chi2, df = df_model, lower.tail = FALSE)
mcfadden <- 1 - ll_full / ll_null
cox_snell <- 1 - exp(2 * (ll_null - ll_full) / n)
nagelkerke <- cox_snell / (1 - exp(2 * ll_null / n))

cat("\n--- Fit diagnostics ---\n")
cat(sprintf("n = %d\n", n))
cat(sprintf("Log-likelihood (full): %.2f\n", ll_full))
cat(sprintf("Log-likelihood (null): %.2f\n", ll_null))
cat(sprintf("LR chi^2 (%d) = %.2f, p = %.3g\n", df_model, lr_chi2, lr_p))
cat(sprintf("McFadden  pseudo-R^2 = %.3f\n", mcfadden))
cat(sprintf("Cox-Snell pseudo-R^2 = %.3f\n", cox_snell))
cat(sprintf("Nagelkerke pseudo-R^2 = %.3f\n", nagelkerke))

# Extract coefficients, SEs, p-values, 95% CIs, odds ratios
coefs <- summary(fit)$coefficients     # rows = clusters (non-reference), cols = predictors+intercept
ses   <- summary(fit)$standard.errors
z     <- coefs / ses
pvals <- 2 * (1 - pnorm(abs(z)))

clusters_non_ref <- rownames(coefs)
var_names <- colnames(coefs)

rows <- list()
for (cl in clusters_non_ref) {
  for (v in var_names) {
    beta <- coefs[cl, v]
    se <- ses[cl, v]
    p <- pvals[cl, v]
    or <- exp(beta)
    or_lo <- exp(beta - 1.96 * se)
    or_hi <- exp(beta + 1.96 * se)
    sig <- ifelse(p < 0.001, "***",
            ifelse(p < 0.01,  "**",
              ifelse(p < 0.05, "*", "ns")))
    rows[[length(rows) + 1L]] <- data.frame(
      cluster = cl, predictor = v,
      beta = beta, OR = or, OR_lo = or_lo, OR_hi = or_hi,
      p = p, sig = sig,
      stringsAsFactors = FALSE
    )
  }
}
result <- do.call(rbind, rows)

cat("\n--- Odds ratios (vs Moderate Isolated reference) ---\n")
print(result, row.names = FALSE, digits = 3)

# Persist outputs
write.csv(result,
          file.path(out_dir, "step30_multinomial_coefs.csv"),
          row.names = FALSE)

fit_lines <- c(
  sprintf("n = %d", n),
  sprintf("LR chi^2 (%d) = %.2f, p = %.3g", df_model, lr_chi2, lr_p),
  sprintf("McFadden  pseudo-R^2 = %.3f", mcfadden),
  sprintf("Cox-Snell pseudo-R^2 = %.3f", cox_snell),
  sprintf("Nagelkerke pseudo-R^2 = %.3f", nagelkerke),
  "",
  "Reference category: Moderate Isolated.",
  "Predictors:",
  "  age_c     age - 75 (years)",
  "  female    1 if gender == 2 (female), else 0",
  "  yedu_c    yedu - 8 (years of education centred at sample mean)",
  "  single    1 if living alone, else 0",
  "  home_own  1 if homeowner, else 0"
)
writeLines(fit_lines, file.path(out_dir, "step30_multinomial_fit.txt"))

cat("\nWrote", file.path(out_dir, "step30_multinomial_coefs.csv"), "\n")
cat("Wrote", file.path(out_dir, "step30_multinomial_fit.txt"), "\n")
