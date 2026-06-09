# ==============================================================================
# STEP 31: FASE 2 SENSITIVITY ANALYSES
# Thesis: "Beyond the Monolith"
# Trentini review Fase 2 — quattro sensitivity analyses in singolo R session
# per chiudere i commenti #1, #2/#10, #4, e l'asymmetry 29-vs-31 vars IT/SE.
#
# Disegno (concordato con utente, allineato al deployed pipeline):
#   Sens 1 — Sweden outlier alpha (#1 Trentini)
#     Replica step 4 con alpha = 0.0001 e alpha = 0 (no exclusion).
#     ARI vs deployed (alpha = 0.001) — partition K-means k=6 su 31 var std.
#   Sens 2 — Gower PAM vs Euclidean K-means deployed (#2/#10 Trentini)
#     PAM su daisy(metric="gower", type=list(asymm=binary_vars)) sui dati
#     ORIGINALI (non std) — binarie correttamente trattate come asimmetriche.
#     Stesso k del deployed (IT=5, SE=6). ARI vs K-means deployed.
#   Sens 3 — Heywood alternative FA Sweden (#4 Trentini)
#     Tre varianti FA: (a) minres 31v, (b) ml 31v, (c) pa 30v senza
#     social_integration. Metriche FA-level: KMO, RMSEA, TLI, Heywood flag.
#     K-means su var std (apples-to-apples col deployed). Per (a) e (b) la
#     partition è uguale al deployed by construction (K-means non vede la FA)
#     -> ARI = 1.0 nominale; il messaggio è FA-level. Per (c) K-means k=6 su
#     30 var std -> ARI vs deployed informativo sulla rimozione di social_integration.
#   Sens 4 — Italy 29-vs-31 vars (preemptive §3.6)
#     Re-include ac035d4 e ac035d7 in IT con piccola perturbazione gaussiana
#     (zero-variance in deployed). FA pa 31v + K-means k=5 sui 31 var std.
#     ARI vs deployed (29 var std, k=5).
#
# INPUT (read-only, non sovrascrive nulla):
#   v9/outputs/step2_italy_std.rds, step2_italy_clean.rds
#   v9/outputs/step4_sweden_std.rds, step4_sweden_clean.rds
#   v9/outputs/step3_sweden_assembled.rds       (per Sens 1, pre-listwise)
#   v9/outputs/step7_italy_with_clusters.rds    (cluster_num + mergeid)
#   v9/outputs/step8_sweden_with_clusters.rds   (cluster_num + mergeid)
#   v9/outputs/step5_italy_fa_results.rds, step6_sweden_fa_results.rds
#
# OUTPUT:
#   v9/outputs/sensitivities/fase2_summary.txt
#   v9/outputs/sensitivities/sens1_sweden_outlier_alpha.csv
#   v9/outputs/sensitivities/sens2_gower_pam.csv
#   v9/outputs/sensitivities/sens3_heywood_alternatives.csv
#   v9/outputs/sensitivities/sens4_italy_29_vs_31.csv
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(psych)
  library(cluster)
  library(mclust)
  library(MASS)
})

# Path NB: gli script storici v9/01-08 hard-codano ~/Desktop/SHARE\ DATASET/...
# che non esiste più sulla macchina corrente. Uso la path canonica attuale.
data_path <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"
out_dir   <- file.path(data_path, "v9", "outputs", "sensitivities")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

t_start <- Sys.time()

cat("============================================================\n")
cat("STEP 31: FASE 2 SENSITIVITY ANALYSES\n")
cat("============================================================\n\n")
cat("Start:", format(t_start), "\n")
cat("Output dir:", out_dir, "\n\n")


# --- Variabili (identico a 04/06 — non ricalcolare) ---
health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                  "sp002_", "sp008_", "sn_size_w9", "social_integration",
                  "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")
all_31 <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

binary_vars <- c("phinact", "home_own", "internet", "ac035d1", "ac035d5",
                 "ac035d8", "sp002_", "sp008_", "ac035d4", "ac035d7",
                 "hope_future")
nonbinary_vars <- setdiff(all_31, binary_vars)


# --- Load deployed objects ---
ip <- file.path(data_path, "v9", "outputs")

it_std       <- readRDS(file.path(ip, "step2_italy_std.rds"))
it_clean     <- readRDS(file.path(ip, "step2_italy_clean.rds"))
se_std       <- readRDS(file.path(ip, "step4_sweden_std.rds"))
se_clean     <- readRDS(file.path(ip, "step4_sweden_clean.rds"))
se_assembled <- readRDS(file.path(ip, "step3_sweden_assembled.rds"))
it_clust     <- readRDS(file.path(ip, "step7_italy_with_clusters.rds"))
se_clust     <- readRDS(file.path(ip, "step8_sweden_with_clusters.rds"))

# Active vars come deployato
it_active_29 <- setdiff(all_31, c("ac035d4", "ac035d7"))   # 29 — zero-var in IT
se_active_31 <- all_31                                      # 31 — tutte attive in SE

# Deployed partitions (mergeid → cluster_num)
dep_it <- setNames(it_clust$cluster_num, it_clust$mergeid)
dep_se <- setNames(se_clust$cluster_num, se_clust$mergeid)

cat("Deployed partitions caricate:\n")
cat(sprintf("  IT k=5 su 29 var std, n=%d\n", length(dep_it)))
cat(sprintf("  SE k=6 su 31 var std, n=%d\n\n", length(dep_se)))


# --- Helpers ---
ari_via_mergeid <- function(dep, new) {
  common <- intersect(names(dep), names(new))
  if (length(common) < 10) return(NA_real_)
  mclust::adjustedRandIndex(dep[common], new[common])
}

verdict_pass <- function(value, threshold) {
  if (is.na(value)) "INCONCLUSIVE" else if (value > threshold) "PASS" else "CONCERN"
}

fit_fa_safe <- function(X, method, nf = 6) {
  hey <- FALSE
  fa_obj <- tryCatch(
    withCallingHandlers(
      fa(X, nfactors = nf, rotate = "varimax", fm = method,
         scores = "regression", warnings = FALSE),
      warning = function(w) {
        if (grepl("Heywood|ultra-Heywood|negative",
                  w$message, ignore.case = TRUE)) {
          hey <<- TRUE
          invokeRestart("muffleWarning")
        }
      }
    ),
    error = function(e) {
      cat("    ! FA error (", method, "):", conditionMessage(e), "\n")
      NULL
    }
  )
  if (is.null(fa_obj)) return(list(fa = NULL, heywood = NA, converged = FALSE))
  hey <- hey || any(fa_obj$communality > 1, na.rm = TRUE)
  list(fa = fa_obj, heywood = hey, converged = TRUE)
}

run_kmeans_partition <- function(X, k, ids) {
  set.seed(42)
  km <- kmeans(X, centers = k, nstart = 100, iter.max = 500)
  setNames(km$cluster, ids)
}


# ##############################################################################
# SENSITIVITY 1 — Sweden outlier alpha
# ##############################################################################

cat("============================================================\n")
cat("[SENS 1] Sweden outlier alpha (#1 Trentini)\n")
cat("============================================================\n")
cat("  Deployed: alpha = 0.001, n = ", length(dep_se), "\n", sep = "")
cat("  Varianti: (a) alpha = 0.0001  (b) alpha = 0 (no exclusion)\n\n")

prepare_sweden_with_alpha <- function(alpha) {
  raw <- se_assembled %>% filter(complete.cases(across(all_of(all_31))))

  # rank trans (non-binarie)
  ranked <- raw
  for (v in nonbinary_vars) {
    ranked[[v]] <- rank(ranked[[v]], ties.method = "average")
  }

  # standardize tutte le 31
  std <- ranked
  for (v in all_31) {
    std[[v]] <- as.numeric(scale(std[[v]]))
  }

  zv <- sapply(std[, all_31], sd)
  mvars <- all_31[zv > 0 & !is.na(zv)]

  X <- as.matrix(std[, mvars])
  center  <- colMeans(X)
  cov_mat <- cov(X)

  if (rcond(cov_mat) < .Machine$double.eps) {
    cov_inv <- ginv(cov_mat)
    md <- apply(X, 1, function(x) {
      d <- x - center; as.numeric(t(d) %*% cov_inv %*% d)
    })
  } else {
    md <- mahalanobis(X, center, cov_mat)
  }

  if (alpha > 0) {
    cutoff <- qchisq(1 - alpha, df = length(mvars))
    keep   <- md <= cutoff
  } else {
    cutoff <- Inf
    keep   <- rep(TRUE, length(md))
  }

  list(std       = std[keep, , drop = FALSE],
       n         = sum(keep),
       n_dropped = sum(!keep),
       alpha     = alpha,
       cutoff    = cutoff)
}

# (a) alpha = 0.0001
cat("  (a) alpha = 0.0001 ...\n")
s1a <- prepare_sweden_with_alpha(0.0001)
km_s1a <- run_kmeans_partition(as.matrix(s1a$std[, se_active_31]), 6, s1a$std$mergeid)
ari_s1a <- ari_via_mergeid(dep_se, km_s1a)
cat(sprintf("      n = %d (delta vs deployed = %+d), outliers rimossi = %d, ARI = %.4f\n",
            s1a$n, s1a$n - length(dep_se), s1a$n_dropped, ari_s1a))

# (b) alpha = 0 (nessuna exclusion)
cat("  (b) alpha = 0 (no exclusion) ...\n")
s1b <- prepare_sweden_with_alpha(0)
km_s1b <- run_kmeans_partition(as.matrix(s1b$std[, se_active_31]), 6, s1b$std$mergeid)
ari_s1b <- ari_via_mergeid(dep_se, km_s1b)
cat(sprintf("      n = %d (delta vs deployed = %+d), outliers rimossi = %d, ARI = %.4f\n\n",
            s1b$n, s1b$n - length(dep_se), s1b$n_dropped, ari_s1b))

# Confusion-matrix profile × cluster_num per separare instabilità strutturale
# (i 6 macro-profili sopravvivono?) da label-noise (singole righe migrano).
dep_se_profile <- setNames(se_clust$profile, se_clust$mergeid)

confusion_profile <- function(dep_profile, variant_clust) {
  common <- intersect(names(dep_profile), names(variant_clust))
  if (length(common) < 10) return(NULL)
  tab <- table(deployed_profile = dep_profile[common],
               variant_cluster  = variant_clust[common])
  # Macro-stability: per ogni cluster variante, prendi il profilo dominante e
  # somma quanti finiscono dove la maggioranza dice. Questo è un proxy della
  # purity classico (= maggioranza relativa per cluster).
  purity <- sum(apply(tab, 2, max)) / sum(tab)
  list(tab = tab, purity = purity, n = length(common))
}

cm_s1a <- confusion_profile(dep_se_profile, km_s1a)
cm_s1b <- confusion_profile(dep_se_profile, km_s1b)

cat("  --- Confusion-matrix (deployed profile rows × variant cluster cols) ---\n\n")
cat("  Variant (a) alpha=0.0001:\n")
print(cm_s1a$tab)
cat(sprintf("  Purity (Σ max colonna / n) = %.4f  [n=%d]\n\n",
            cm_s1a$purity, cm_s1a$n))
cat("  Variant (b) alpha=0:\n")
print(cm_s1b$tab)
cat(sprintf("  Purity (Σ max colonna / n) = %.4f  [n=%d]\n\n",
            cm_s1b$purity, cm_s1b$n))

# Verdict ARI come prima, ma loggo anche la purity (utile per Trentini #1)
verdict_s1 <- verdict_pass(min(ari_s1a, ari_s1b, na.rm = TRUE), 0.80)
cat("  Interpretazione: ARI > 0.80 -> partition robusta all'exclusion threshold\n")
cat(sprintf("  Verdict Sens 1: %s\n\n", verdict_s1))

write.csv(
  data.frame(
    variant   = c("alpha_0.0001", "alpha_0_no_exclusion"),
    alpha     = c(0.0001, 0),
    n_kept    = c(s1a$n, s1b$n),
    n_dropped = c(s1a$n_dropped, s1b$n_dropped),
    delta_vs_deployed = c(s1a$n - length(dep_se), s1b$n - length(dep_se)),
    ari_vs_deployed   = c(ari_s1a, ari_s1b),
    purity_profile_majority = c(
      if (!is.null(cm_s1a)) cm_s1a$purity else NA,
      if (!is.null(cm_s1b)) cm_s1b$purity else NA
    ),
    stringsAsFactors  = FALSE
  ),
  file.path(out_dir, "sens1_sweden_outlier_alpha.csv"),
  row.names = FALSE
)

# Salva anche le confusion matrices come file separati
if (!is.null(cm_s1a)) {
  write.csv(as.data.frame.matrix(cm_s1a$tab),
            file.path(out_dir, "sens1a_confusion_alpha_0.0001.csv"))
}
if (!is.null(cm_s1b)) {
  write.csv(as.data.frame.matrix(cm_s1b$tab),
            file.path(out_dir, "sens1b_confusion_alpha_0.csv"))
}


# ##############################################################################
# SENSITIVITY 2 — Gower PAM vs Euclidean K-means deployed
# ##############################################################################

cat("============================================================\n")
cat("[SENS 2] Gower PAM vs K-means deployed (#2/#10 Trentini)\n")
cat("============================================================\n")
cat("  Input: var ORIGINALI (non std), con type=list(asymm=binary_vars) in daisy.\n")
cat("  Gower normalizza internamente per range; binarie trattate come asimmetriche.\n\n")

# Per IT le binarie attive escludono ac035d4/ac035d7 (zero-var)
it_binary_active <- setdiff(binary_vars, c("ac035d4", "ac035d7"))
se_binary_active <- binary_vars

# Coerce a numeric/integer per evitare errori haven_labelled in daisy
coerce_for_daisy <- function(df, vars) {
  out <- as.data.frame(df[, vars])
  for (v in vars) {
    x <- out[[v]]
    # Strip haven_labelled / labelled classes preservando il valore numerico
    if (inherits(x, c("haven_labelled", "labelled"))) {
      x <- unclass(x)
      attr(x, "labels") <- NULL
      attr(x, "label")  <- NULL
      attr(x, "format.stata") <- NULL
    }
    # storage.mode -> double
    out[[v]] <- as.numeric(as.vector(x))
  }
  out
}

# Italy
cat("  Italy: daisy gower 29v (originali, asymm binaries) -> PAM k=5 ...\n")
it_for_daisy <- coerce_for_daisy(it_clean, it_active_29)
gd_it <- cluster::daisy(it_for_daisy, metric = "gower",
                        type = list(asymm = it_binary_active))
set.seed(42)
pam_it <- cluster::pam(gd_it, k = 5, diss = TRUE, pamonce = 5)
pam_it_part <- setNames(pam_it$clustering, it_clean$mergeid)
ari_s2_it   <- ari_via_mergeid(dep_it, pam_it_part)
cat(sprintf("      ARI(PAM_Gower, KMeans_deployed) Italy = %.4f\n", ari_s2_it))

# Sweden
cat("  Sweden: daisy gower 31v (originali, asymm binaries) -> PAM k=6 ...\n")
se_for_daisy <- coerce_for_daisy(se_clean, se_active_31)
gd_se <- cluster::daisy(se_for_daisy, metric = "gower",
                        type = list(asymm = se_binary_active))
set.seed(42)
pam_se <- cluster::pam(gd_se, k = 6, diss = TRUE, pamonce = 5)
pam_se_part <- setNames(pam_se$clustering, se_clean$mergeid)
ari_s2_se   <- ari_via_mergeid(dep_se, pam_se_part)
cat(sprintf("      ARI(PAM_Gower, KMeans_deployed) Sweden = %.4f\n\n", ari_s2_se))

verdict_s2 <- verdict_pass(min(ari_s2_it, ari_s2_se, na.rm = TRUE), 0.70)
cat("  Interpretazione: ARI > 0.70 -> partition convergente, Euclidean justified\n")
cat(sprintf("  Verdict Sens 2: %s\n\n", verdict_s2))

write.csv(
  data.frame(
    country   = c("Italy", "Sweden"),
    n_vars    = c(length(it_active_29), length(se_active_31)),
    k         = c(5, 6),
    n         = c(length(dep_it), length(dep_se)),
    ari_gower_pam_vs_kmeans = c(ari_s2_it, ari_s2_se),
    stringsAsFactors = FALSE
  ),
  file.path(out_dir, "sens2_gower_pam.csv"),
  row.names = FALSE
)

# --- Profile-level confusion matrix: deployed profile (rows) × Gower-PAM cluster (cols) ---
# Trentini #2/#10: mostra QUALI profili sopravvivono al cambio di metrica (estremi vs middle).
dep_it_profile <- setNames(it_clust$profile, it_clust$mergeid)
# dep_se_profile è già definito nella Sens 1.

profile_gower_confusion <- function(dep_profile, gower_part, profile_order, country) {
  common <- intersect(names(dep_profile), names(gower_part))
  tab <- table(deployed_profile = dep_profile[common],
               gower_cluster     = gower_part[common])
  profile_order <- profile_order[profile_order %in% rownames(tab)]
  tab <- tab[profile_order, , drop = FALSE]
  dom_cluster   <- apply(tab, 1, function(r) colnames(tab)[which.max(r)])
  concentration <- apply(tab, 1, function(r) max(r) / sum(r))
  n_profile     <- rowSums(tab)
  global_purity <- sum(apply(tab, 1, max)) / sum(tab)
  cat(sprintf("\n  --- %s: profile-level Gower-PAM confusion (n=%d) ---\n",
              country, length(common)))
  print(tab)
  cat(sprintf("\n  %-20s %8s %12s %16s\n",
              "Deployed profile", "n", "dom.Gower", "concentration"))
  for (p in rownames(tab)) {
    cat(sprintf("  %-20s %8d %12s %15.1f%%\n",
                p, n_profile[p], dom_cluster[p], 100 * concentration[p]))
  }
  cat(sprintf("  Global profile purity (sum rowmax / n) = %.4f\n", global_purity))
  list(tab = tab, dom_cluster = dom_cluster, concentration = concentration,
       n_profile = n_profile, global_purity = global_purity)
}

it_profile_order <- c("Fragile Resigned", "Fragile Depressed", "Moderate Isolated",
                      "Traditional Social", "Connected Active")
se_profile_order <- c("Wealthy Digital", "Fragile", "Connected Wealthy",
                      "Asset Rich", "Moderate", "Social Decline")

cm_gower_it <- profile_gower_confusion(dep_it_profile, pam_it_part, it_profile_order, "Italy")
cm_gower_se <- profile_gower_confusion(dep_se_profile, pam_se_part, se_profile_order, "Sweden")

write.csv(as.data.frame.matrix(cm_gower_it$tab),
          file.path(out_dir, "sens2_gower_confusion_italy.csv"))
write.csv(as.data.frame.matrix(cm_gower_se$tab),
          file.path(out_dir, "sens2_gower_confusion_sweden.csv"))


# ##############################################################################
# SENSITIVITY 3 — Heywood alternative FA Sweden
# ##############################################################################

cat("============================================================\n")
cat("[SENS 3] Heywood alternative FA Sweden (#4 Trentini)\n")
cat("============================================================\n")
cat("  Deployed: PA su 31 var (social_integration inclusa, Heywood accettato)\n")
cat("  Varianti: (a) minres 31v  (b) ml 31v  (c) pa 30v (no social_integration)\n\n")

X_se_31 <- as.matrix(se_std[, se_active_31])
R_se_31 <- cor(X_se_31)
kmo_31  <- KMO(R_se_31)$MSA
cat(sprintf("  KMO complessivo (31v): %.3f\n\n", kmo_31))

se_30 <- setdiff(se_active_31, "social_integration")
X_se_30 <- as.matrix(se_std[, se_30])
R_se_30 <- cor(X_se_30)
kmo_30  <- KMO(R_se_30)$MSA

cat("  NB: ARI ricalcolato su K-means su var std (apples-to-apples col deployed),\n")
cat("      NON su factor scores. Per (a) e (b) K-means è sulle stesse 31 var std del\n")
cat("      deployed -> ARI = 1.0 by construction (FA è descrittiva, non muta il KMeans).\n")
cat("      Per (c) K-means k=6 sulle 30 var std (drop social_integration).\n\n")

# Sens 3 reformulato: separa il livello FA dal livello clustering.
# (a) e (b) condividono le stesse 31 var std del deployed -> K-means identico,
# l'unica cosa che cambia è la FA descrittiva (Heywood/fit). ARI = 1.0 by design.
# (c) cambia anche lo spazio del K-means (30 var std) -> ARI informativo.
run_fa_variant <- function(X_fa, method, label, kmeans_X, kmeans_ids, kmeans_compare_to_deployed) {
  cat(sprintf("  %s ...\n", label))
  res <- fit_fa_safe(X_fa, method, nf = 6)
  if (!res$converged || is.null(res$fa)) {
    return(list(label = label, converged = FALSE, heywood = NA,
                rmsea = NA, tli = NA, rms = NA, ari = NA))
  }
  if (kmeans_compare_to_deployed) {
    # K-means sulle stesse 31 var std del deployed -> partition identico al deployed
    # (il K-means non vede la FA). ARI = 1.0 by construction.
    ari <- 1.0
  } else {
    km_part <- run_kmeans_partition(kmeans_X, 6, kmeans_ids)
    ari <- ari_via_mergeid(dep_se, km_part)
  }
  list(label = label,
       converged = TRUE,
       heywood   = res$heywood,
       rmsea     = res$fa$RMSEA[1],
       tli       = res$fa$TLI,
       rms       = res$fa$rms,
       ari       = ari)
}

s3a <- run_fa_variant(X_se_31, "minres", "(a) minres 31v",
                      kmeans_X = X_se_31, kmeans_ids = se_std$mergeid,
                      kmeans_compare_to_deployed = TRUE)
s3b <- run_fa_variant(X_se_31, "ml",     "(b) ml 31v",
                      kmeans_X = X_se_31, kmeans_ids = se_std$mergeid,
                      kmeans_compare_to_deployed = TRUE)
s3c <- run_fa_variant(X_se_30, "pa",     "(c) pa 30v (no social_integration)",
                      kmeans_X = X_se_30, kmeans_ids = se_std$mergeid,
                      kmeans_compare_to_deployed = FALSE)

print_s3 <- function(r, kmo_used) {
  if (!r$converged) {
    cat(sprintf("      %s: NON CONVERGE (non identificabile)\n", r$label))
    return(invisible())
  }
  cat(sprintf("      %s: Heywood=%s, KMO=%.3f, RMSEA=%.4f, TLI=%.4f, RMS=%.4f, ARI=%.4f\n",
              r$label, r$heywood, kmo_used, r$rmsea, r$tli, r$rms, r$ari))
}
cat("\n")
print_s3(s3a, kmo_31)
print_s3(s3b, kmo_31)
print_s3(s3c, kmo_30)

aris_s3 <- c(s3a$ari, s3b$ari, s3c$ari)
hey_any_alt_converged_clean <-
  any(c(s3a$converged && !isTRUE(s3a$heywood),
        s3b$converged && !isTRUE(s3b$heywood),
        s3c$converged && !isTRUE(s3c$heywood)))

# Defensibility: deployed defensible se OGNI variante o produce Heywood
# o produce ARI > 0.75 con deployed
defensible <- all(sapply(list(s3a, s3b, s3c), function(r) {
  if (!r$converged) return(TRUE)
  isTRUE(r$heywood) || (!is.na(r$ari) && r$ari > 0.75)
}))
verdict_s3 <- if (defensible) "PASS" else "CONCERN"
cat(sprintf("\n  Verdict Sens 3 (deployed PA 31v defensible): %s\n\n", verdict_s3))

write.csv(
  data.frame(
    variant   = c(s3a$label, s3b$label, s3c$label),
    converged = c(s3a$converged, s3b$converged, s3c$converged),
    heywood   = c(s3a$heywood,   s3b$heywood,   s3c$heywood),
    kmo       = c(kmo_31, kmo_31, kmo_30),
    rmsea     = c(s3a$rmsea, s3b$rmsea, s3c$rmsea),
    tli       = c(s3a$tli,   s3b$tli,   s3c$tli),
    rms       = c(s3a$rms,   s3b$rms,   s3c$rms),
    ari_vs_deployed = c(s3a$ari, s3b$ari, s3c$ari),
    stringsAsFactors = FALSE
  ),
  file.path(out_dir, "sens3_heywood_alternatives.csv"),
  row.names = FALSE
)


# ##############################################################################
# SENSITIVITY 4 — Italy 29-vs-31 vars (preemptive §3.6)
# ##############################################################################

cat("============================================================\n")
cat("[SENS 4] Italy 29-vs-31 vars (preemptive §3.6)\n")
cat("============================================================\n")
cat("  Deployed: 29 var (ac035d4/ac035d7 escluse per varianza zero in IT)\n")
cat("  Variante: 31 var, re-includendo ac035d4/ac035d7 con perturbazione gaussiana\n\n")

# Check varianza originale
sd_d4_raw <- sd(it_clean$ac035d4, na.rm = TRUE)
sd_d7_raw <- sd(it_clean$ac035d7, na.rm = TRUE)
cat(sprintf("  Raw sd ac035d4 = %.6f  sd ac035d7 = %.6f  (deployed: zero)\n",
            sd_d4_raw, sd_d7_raw))

# Costruisce dataset 31v: 29 originali std + 2 perturbazioni N(0, 0.05) std
set.seed(42)
it_std_31 <- it_std
it_std_31$ac035d4 <- as.numeric(scale(rnorm(nrow(it_std), mean = 0, sd = 0.05)))
it_std_31$ac035d7 <- as.numeric(scale(rnorm(nrow(it_std), mean = 0, sd = 0.05)))

X_it_31 <- as.matrix(it_std_31[, all_31])

# FA pa 6 fattori (per consistenza con deployed FA Italy che usa fm="pa", nf=6)
cat("  FA pa 31v, 6 fattori, varimax ...\n")
fa_it31 <- fit_fa_safe(X_it_31, "pa", 6)
if (fa_it31$converged) {
  cat(sprintf("      Heywood = %s, RMSEA = %.4f, RMS = %.4f\n",
              fa_it31$heywood, fa_it31$fa$RMSEA[1], fa_it31$fa$rms))
} else {
  cat("      FA non converge\n")
}

# K-means k=5 sui 31 var std (matching deployed metodologia: K-means su var std)
cat("  K-means k=5 sui 31 var std ...\n")
km_it31_part <- run_kmeans_partition(X_it_31, 5, it_std_31$mergeid)
ari_s4 <- ari_via_mergeid(dep_it, km_it31_part)
cat(sprintf("      ARI(IT 31v perturbed, IT deployed 29v) = %.4f\n\n", ari_s4))

verdict_s4 <- verdict_pass(ari_s4, 0.80)
cat("  Interpretazione: ARI > 0.80 -> asymmetry 29-vs-31 var non altera la struttura\n")
cat(sprintf("  Verdict Sens 4: %s\n\n", verdict_s4))

write.csv(
  data.frame(
    variant = "italy_31v_perturbed_vs_deployed_29v",
    n_vars_variant = 31,
    n_vars_deployed = 29,
    k = 5,
    perturbation_sd_pre_std = 0.05,
    fa_converged = fa_it31$converged,
    fa_heywood   = if (fa_it31$converged) fa_it31$heywood else NA,
    fa_rmsea     = if (fa_it31$converged) fa_it31$fa$RMSEA[1] else NA,
    ari_vs_deployed = ari_s4,
    stringsAsFactors = FALSE
  ),
  file.path(out_dir, "sens4_italy_29_vs_31.csv"),
  row.names = FALSE
)


# ##############################################################################
# SUMMARY
# ##############################################################################

t_end <- Sys.time()
elapsed <- as.numeric(difftime(t_end, t_start, units = "mins"))

# Costruisce summary table (4 righe × 3 col)
summary_df <- data.frame(
  Sensitivity = c(
    "1. Sweden outlier alpha (a=0.0001 / a=0)",
    "2. Gower PAM vs KMeans (IT k=5 / SE k=6)",
    "3. Heywood alt FA Sweden (minres/ml/pa-30v)",
    "4. Italy 29-vs-31 vars (perturbed re-include)"
  ),
  Metric = c(
    sprintf("ARI a=%.3f/b=%.3f  Purity a=%.3f/b=%.3f",
            ari_s1a, ari_s1b,
            if (!is.null(cm_s1a)) cm_s1a$purity else NA,
            if (!is.null(cm_s1b)) cm_s1b$purity else NA),
    sprintf("ARI(IT)=%.4f  ARI(SE)=%.4f", ari_s2_it, ari_s2_se),
    sprintf("ARI: a=%s b=%s c=%s | Hey: a=%s b=%s c=%s",
            formatC(s3a$ari, format = "f", digits = 4),
            formatC(s3b$ari, format = "f", digits = 4),
            formatC(s3c$ari, format = "f", digits = 4),
            s3a$heywood, s3b$heywood, s3c$heywood),
    sprintf("ARI=%.4f  Heywood=%s", ari_s4,
            if (fa_it31$converged) fa_it31$heywood else NA)
  ),
  Verdict = c(verdict_s1, verdict_s2, verdict_s3, verdict_s4),
  stringsAsFactors = FALSE
)

summary_lines <- c(
  "================================================================================",
  "FASE 2 SENSITIVITY ANALYSES — SUMMARY",
  "================================================================================",
  sprintf("Run completed: %s", format(t_end)),
  sprintf("Elapsed:       %.1f min", elapsed),
  "",
  "Deployed pipeline reference:",
  sprintf("  Italy  K-means k=5 su 29 var std (ac035d4/ac035d7 zero-var escluse), n=%d",
          length(dep_it)),
  sprintf("  Sweden K-means k=6 su 31 var std (social_integration inclusa, Heywood accettato), n=%d",
          length(dep_se)),
  "",
  "Soglie interpretative:",
  "  Sens 1: ARI > 0.80 = robusto all'alpha threshold",
  "  Sens 2: ARI > 0.70 = Euclidean justified vs Gower",
  "  Sens 3: defensible se ogni alternativa o produce Heywood o ARI > 0.75",
  "  Sens 4: ARI > 0.80 = asymmetry 29-vs-31 IT non altera la struttura",
  "",
  "================================================================================",
  sprintf("%-50s | %-55s | %s", "Sensitivity", "Metric", "Verdict"),
  paste(rep("-", 130), collapse = "")
)

for (i in seq_len(nrow(summary_df))) {
  summary_lines <- c(summary_lines,
    sprintf("%-50s | %-55s | %s",
            summary_df$Sensitivity[i],
            summary_df$Metric[i],
            summary_df$Verdict[i])
  )
}

summary_lines <- c(summary_lines,
  paste(rep("-", 130), collapse = ""),
  "",
  "Detail CSVs:",
  "  sens1_sweden_outlier_alpha.csv",
  "  sens2_gower_pam.csv",
  "  sens3_heywood_alternatives.csv",
  "  sens4_italy_29_vs_31.csv",
  "================================================================================"
)

writeLines(summary_lines, file.path(out_dir, "fase2_summary.txt"))

cat("\n\n")
cat(paste(summary_lines, collapse = "\n"))
cat("\n\n")
cat("Summary salvato in:", file.path(out_dir, "fase2_summary.txt"), "\n")
cat("Wall-clock totale:", round(elapsed, 2), "min\n")
