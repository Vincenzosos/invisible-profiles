# ==============================================================================
# STEP 11: HEALTHCARE UTILIZATION GAP — "il dato forte" del brief
# Thesis: "Invisible Profiles"
#
# Brief (lines 142-159): tabella Isolati Moderati vs Sociali Tradizionali in Italia
# (stesse condizioni fisiche, rete sociale diversa) + cross-country aggregato.
#
# Pipeline:
#   Part A — Estrazione variabili healthcare da SHARE raw (hc.dta)
#   Part B — Merge con i file clusterizzati Step 7 (IT) e Step 8 (SE)
#   Part C — Italia: Isolati Moderati vs Traditional Social (t-test/chi²)
#   Part D — Cross-country aggregato: IT vs SE su variabili healthcare
#   Part E — Healthcare gap per profilo matched pair (IT vs SE)
#   Part F — Salvataggio
#
# VARIABILI SHARE (hc.dta):
#   hc602_    = Doctor visits (times talked to medical doctor/nurse last 12m)
#   hc876_    = GP contacts
#   hc877_    = Specialist contacts
#   hc010_    = Dentist visit last 12m (binary)
#   hc012_    = Hospitalised last 12m (binary)
#   hc014_    = Nights in hospital
#   hc841d1..d7 = Forgone care due to cost (per type) → derived "any forgone cost"
#
# INPUT:  v9/step7_italy_with_clusters.rds
#         v9/step8_sweden_with_clusters.rds
#         sharew9_rel9-0-0_hc.dta
# OUTPUT: v9/step11_healthcare_italy_isolati_vs_sociali.rds
#         v9/step11_healthcare_cross_country.rds
#         v9/step11_healthcare_by_pair.rds
# ==============================================================================

library(dplyr)
if (!requireNamespace("haven", quietly = TRUE)) install.packages("haven", quiet = TRUE)
library(haven)

# Se poLCA/MASS sono caricati (da Step 10), detach per evitare mask di dplyr::select
if ("package:MASS" %in% search()) {
  cat("  (detaching MASS to unmask dplyr::select)\n")
  try(detach("package:MASS", unload = FALSE), silent = TRUE)
}
# Safety: alias locale per select
select <- dplyr::select

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"

cat("============================================================\n")
cat("STEP 11: HEALTHCARE UTILIZATION GAP\n")
cat("============================================================\n\n")


# ##############################################################################
# PART A: ESTRAZIONE VARIABILI HEALTHCARE DA SHARE RAW
# ##############################################################################

cat("============================================================\n")
cat("PART A: ESTRAZIONE SHARE HEALTHCARE VARIABLES\n")
cat("============================================================\n\n")

hc_file <- file.path(data_path, "_share_data", "sharew9_rel9-0-0_hc.dta")
hc_raw <- read_dta(hc_file, col_select = c(
  "mergeid", "country",
  "hc010_",  # dentist
  "hc012_",  # hospitalised
  "hc014_",  # nights in hospital
  "hc602_",  # doctor visits
  "hc876_",  # GP contacts
  "hc877_",  # specialist contacts
  "hc841d1", "hc841d2", "hc841d3", "hc841d4",
  "hc841d5", "hc841d6", "hc841d7", "hc841dno"  # forgone care due to cost
))

cat(sprintf("  Loaded hc.dta: %d rows x %d cols\n", nrow(hc_raw), ncol(hc_raw)))

# Decodifica SHARE: missing codes sono valori negativi (-1..-9)
recode_share <- function(x) ifelse(x < 0, NA, x)

# Ricoding binarie: 1 = Yes, 5 = No (SHARE convention). Ma hc010_ ecc potrebbero
# essere codificate 0/1 dopo il SHARE standard recode. Verifichiamo e
# standardizziamo a 0/1.
recode_binary_share <- function(x) {
  x <- recode_share(x)
  # SHARE: 1=yes, 5=no
  ifelse(x == 1, 1, ifelse(x == 5, 0, NA))
}

hc <- hc_raw %>%
  mutate(
    dentist_12m    = recode_binary_share(hc010_),
    hospitalised   = recode_binary_share(hc012_),
    nights_hosp    = recode_share(hc014_),
    doctor_visits  = recode_share(hc602_),
    gp_contacts    = recode_share(hc876_),
    spec_contacts  = recode_share(hc877_),
    forgone_gp       = recode_binary_share(hc841d1),
    forgone_spec     = recode_binary_share(hc841d2),
    forgone_drugs    = recode_binary_share(hc841d3),
    forgone_dental   = recode_binary_share(hc841d4),
    forgone_optical  = recode_binary_share(hc841d5),
    forgone_home     = recode_binary_share(hc841d6),
    forgone_paidhome = recode_binary_share(hc841d7),
    forgone_none     = recode_binary_share(hc841dno)
  ) %>%
  rowwise() %>%
  mutate(
    # "Any forgone care due to cost" = 1 se almeno una d1..d7 è 1
    forgone_any_cost = as.integer(
      any(c(forgone_gp, forgone_spec, forgone_drugs, forgone_dental,
            forgone_optical, forgone_home, forgone_paidhome) == 1, na.rm = TRUE)
    )
  ) %>%
  ungroup() %>%
  dplyr::select(mergeid, country, dentist_12m, hospitalised, nights_hosp,
                doctor_visits, gp_contacts, spec_contacts, forgone_any_cost)

cat("  Variabili healthcare estratte:\n")
for (v in setdiff(names(hc), c("mergeid", "country"))) {
  n_na <- sum(is.na(hc[[v]]))
  cat(sprintf("    %-17s: %d non-NA (%d NA)\n",
              v, nrow(hc) - n_na, n_na))
}
cat("\n")


# ##############################################################################
# PART B: MERGE CON FILE CLUSTERIZZATI
# ##############################################################################

cat("============================================================\n")
cat("PART B: MERGE CON CLUSTER ASSIGNMENTS\n")
cat("============================================================\n\n")

italy  <- readRDS(file.path(data_path, "v9", "outputs", "step7_italy_with_clusters.rds"))
sweden <- readRDS(file.path(data_path, "v9", "outputs", "step8_sweden_with_clusters.rds"))

# Merge via mergeid
italy_hc <- italy %>%
  left_join(hc %>% filter(country == 16), by = "mergeid")
sweden_hc <- sweden %>%
  left_join(hc %>% filter(country == 13), by = "mergeid")

# Attenzione: SHARE country codes — controlliamo
cat("  Unique countries in hc.dta:\n")
print(sort(unique(hc$country)))
# Italia dovrebbe essere 16, Svezia 13

n_match_it <- sum(!is.na(italy_hc$doctor_visits))
n_match_se <- sum(!is.na(sweden_hc$doctor_visits))
cat(sprintf("\n  Italia: %d/%d righe con healthcare matchato\n",
            n_match_it, nrow(italy_hc)))
cat(sprintf("  Svezia: %d/%d righe con healthcare matchato\n\n",
            n_match_se, nrow(sweden_hc)))


# ##############################################################################
# PART C: ITALIA — ISOLATI MODERATI vs TRADITIONAL SOCIAL
# ##############################################################################

cat("============================================================\n")
cat("PART C: ITALIA — Moderate Isolated vs Traditional Social\n")
cat("(brief line 144-152: condizioni fisiche simili, rete diversa)\n")
cat("============================================================\n\n")

# Definizione: i due profili hanno condizioni fisiche simili ma rete diversa
isolati <- italy_hc %>% filter(profile == "Moderate Isolated")
sociali <- italy_hc %>% filter(profile == "Traditional Social")
cat(sprintf("  n Moderate Isolated: %d\n", nrow(isolati)))
cat(sprintf("  n Traditional Social: %d\n\n", nrow(sociali)))

# Funzione per t-test continuous
compare_continuous <- function(a_vals, b_vals, varname) {
  a_vals <- a_vals[!is.na(a_vals)]
  b_vals <- b_vals[!is.na(b_vals)]
  if (length(a_vals) < 5 || length(b_vals) < 5) {
    return(data.frame(variable = varname, isolati = NA, sociali = NA,
                      gap = NA, t_stat = NA, df = NA, p = NA))
  }
  t_res <- t.test(a_vals, b_vals, var.equal = FALSE)
  data.frame(
    variable = varname,
    isolati  = mean(a_vals),
    sociali  = mean(b_vals),
    gap      = mean(a_vals) - mean(b_vals),
    t_stat   = as.numeric(t_res$statistic),
    df       = as.numeric(t_res$parameter),
    p        = t_res$p.value,
    stringsAsFactors = FALSE
  )
}

# Funzione per chi² test binary
compare_binary <- function(a_vals, b_vals, varname) {
  a_vals <- a_vals[!is.na(a_vals)]
  b_vals <- b_vals[!is.na(b_vals)]
  if (length(a_vals) < 5 || length(b_vals) < 5) {
    return(data.frame(variable = varname, isolati = NA, sociali = NA,
                      gap = NA, t_stat = NA, df = NA, p = NA))
  }
  iso_pct <- 100 * mean(a_vals)
  soc_pct <- 100 * mean(b_vals)
  # Chi² su tabella 2x2
  tab <- matrix(c(sum(a_vals == 1), sum(a_vals == 0),
                  sum(b_vals == 1), sum(b_vals == 0)), ncol = 2)
  chi2 <- suppressWarnings(chisq.test(tab))
  data.frame(
    variable = varname,
    isolati  = iso_pct,
    sociali  = soc_pct,
    gap      = iso_pct - soc_pct,
    t_stat   = as.numeric(chi2$statistic),
    df       = as.numeric(chi2$parameter),
    p        = chi2$p.value,
    stringsAsFactors = FALSE
  )
}

italy_compare <- rbind(
  compare_continuous(isolati$doctor_visits, sociali$doctor_visits, "Doctor visits (12m)"),
  compare_continuous(isolati$gp_contacts,   sociali$gp_contacts,   "GP contacts"),
  compare_continuous(isolati$spec_contacts, sociali$spec_contacts, "Specialist contacts"),
  compare_binary    (isolati$dentist_12m,   sociali$dentist_12m,   "Dentist 12m (%)"),
  compare_binary    (isolati$forgone_any_cost, sociali$forgone_any_cost, "Forgone care cost (%)"),
  compare_continuous(isolati$nights_hosp,   sociali$nights_hosp,   "Nights in hospital")
)

cat("  Tabella (brief line 146-152):\n")
cat("  Variable            | Isolati | Sociali |   Gap  |     p\n")
cat("  ", paste(rep("-", 62), collapse = ""), "\n")
for (i in seq_len(nrow(italy_compare))) {
  r <- italy_compare[i, ]
  sig <- if (is.na(r$p)) "" else if (r$p < 0.001) "***" else if (r$p < 0.01) "**" else if (r$p < 0.05) "*" else ""
  cat(sprintf("  %-20s | %7.2f | %7.2f | %+6.2f | %s %s\n",
              r$variable, r$isolati, r$sociali, r$gap,
              format.pval(r$p, digits = 3), sig))
}

cat("\n  Brief di riferimento:\n")
cat("    Doctor visits/anno: 5.56 / 6.93 | gap -1.36 | p=.006\n")
cat("    GP contacts:        4.49 / 5.67 | gap -1.19 | p=.0003\n")
cat("    Specialist:         1.30 / 2.02 | gap -0.72 | p<.0001\n")
cat("    Dentist (%):          21%/30%   | gap -9pp  | p=.0002\n")
cat("    Forgone care cost:    11%/7%    | gap +4pp  | p=.030\n")
cat("    Nights in hospital: 8.92 / 6.21 | gap +2.71 | p=.127\n")


# ##############################################################################
# PART D: CROSS-COUNTRY AGGREGATO
# ##############################################################################

cat("\n\n============================================================\n")
cat("PART D: CROSS-COUNTRY AGGREGATO (IT vs SE)\n")
cat("============================================================\n\n")

cross_compare <- function(it_vals, se_vals, varname, type = "continuous") {
  it_v <- it_vals[!is.na(it_vals)]
  se_v <- se_vals[!is.na(se_vals)]
  if (length(it_v) < 5 || length(se_v) < 5) return(NULL)

  if (type == "continuous") {
    it_mean <- mean(it_v); se_mean <- mean(se_v)
    t_res <- t.test(se_v, it_v, var.equal = FALSE)
    p <- t_res$p.value
  } else {  # binary
    it_mean <- 100 * mean(it_v); se_mean <- 100 * mean(se_v)
    tab <- matrix(c(sum(it_v == 1), sum(it_v == 0),
                    sum(se_v == 1), sum(se_v == 0)), ncol = 2)
    chi2 <- suppressWarnings(chisq.test(tab))
    p <- chi2$p.value
  }
  data.frame(
    variable = varname,
    italy    = it_mean,
    sweden   = se_mean,
    gap_SE_IT = se_mean - it_mean,
    p        = p,
    stringsAsFactors = FALSE
  )
}

cross_tab <- rbind(
  cross_compare(italy_hc$doctor_visits, sweden_hc$doctor_visits, "Doctor visits", "continuous"),
  cross_compare(italy_hc$gp_contacts,   sweden_hc$gp_contacts,   "GP contacts",   "continuous"),
  cross_compare(italy_hc$spec_contacts, sweden_hc$spec_contacts, "Specialist contacts", "continuous"),
  cross_compare(italy_hc$dentist_12m,   sweden_hc$dentist_12m,   "Dentist (%)",   "binary"),
  cross_compare(italy_hc$hospitalised,  sweden_hc$hospitalised,  "Hospitalised (%)", "binary"),
  cross_compare(italy_hc$forgone_any_cost, sweden_hc$forgone_any_cost, "Forgone care cost (%)", "binary"),
  cross_compare(italy_hc$nights_hosp,   sweden_hc$nights_hosp,   "Nights in hospital", "continuous")
)

cat("  Variable             | Italy  | Sweden | Gap SE-IT |   p\n")
cat("  ", paste(rep("-", 65), collapse = ""), "\n")
for (i in seq_len(nrow(cross_tab))) {
  r <- cross_tab[i, ]
  sig <- if (is.na(r$p)) "" else if (r$p < 0.001) "***" else if (r$p < 0.01) "**" else if (r$p < 0.05) "*" else ""
  cat(sprintf("  %-20s | %6.2f | %6.2f | %+9.2f | %s %s\n",
              r$variable, r$italy, r$sweden, r$gap_SE_IT,
              format.pval(r$p, digits = 3), sig))
}

cat("\n  Brief di riferimento (line 155-160):\n")
cat("    Doctor visits:       7.2 / 7.8 (gap +0.6)\n")
cat("    Hospitalised (%):    10% / 24% (gap +14pp)\n")
cat("    Dentist (%):         30% / 61% (gap +31pp)\n")
cat("    Forgone care cost:    9%/1%  (gap -8pp)\n")


# ##############################################################################
# PART E: HEALTHCARE GAP PER MATCHED PAIR (Step 9 pairs)
# ##############################################################################

cat("\n\n============================================================\n")
cat("PART E: HEALTHCARE GAP PER MATCHED PAIR\n")
cat("============================================================\n\n")

matched_pairs <- data.frame(
  pair_name = c("Fragili", "Connessi", "Sociali", "Dep./Declino"),
  italy_profile  = c("Fragile Resigned", "Connected Active",
                     "Traditional Social", "Fragile Depressed"),
  sweden_profile = c("Fragile", "Connected Wealthy",
                     "Moderate", "Social Decline"),
  stringsAsFactors = FALSE
)

hc_vars_spec <- list(
  list(var = "doctor_visits",    label = "Doctor visits",    type = "continuous"),
  list(var = "gp_contacts",      label = "GP contacts",       type = "continuous"),
  list(var = "spec_contacts",    label = "Specialist",        type = "continuous"),
  list(var = "dentist_12m",      label = "Dentist (%)",       type = "binary"),
  list(var = "hospitalised",     label = "Hospitalised (%)",  type = "binary"),
  list(var = "forgone_any_cost", label = "Forgone cost (%)",  type = "binary")
)

pair_rows <- list()
for (pi in seq_len(nrow(matched_pairs))) {
  pair <- matched_pairs[pi, ]
  cat(sprintf("\n  Pair: %s  (IT %s vs SE %s)\n",
              pair$pair_name, pair$italy_profile, pair$sweden_profile))

  it_sub <- italy_hc  %>% filter(profile == pair$italy_profile)
  se_sub <- sweden_hc %>% filter(profile == pair$sweden_profile)

  for (spec in hc_vars_spec) {
    v <- spec$var
    it_v <- it_sub[[v]][!is.na(it_sub[[v]])]
    se_v <- se_sub[[v]][!is.na(se_sub[[v]])]
    if (length(it_v) < 5 || length(se_v) < 5) {
      cat(sprintf("    %-20s: n troppo piccolo\n", spec$label))
      next
    }
    if (spec$type == "continuous") {
      it_m <- mean(it_v); se_m <- mean(se_v)
      t_res <- t.test(se_v, it_v, var.equal = FALSE)
      p <- t_res$p.value
    } else {
      it_m <- 100 * mean(it_v); se_m <- 100 * mean(se_v)
      tab <- matrix(c(sum(it_v==1), sum(it_v==0),
                      sum(se_v==1), sum(se_v==0)), ncol = 2)
      chi2 <- suppressWarnings(chisq.test(tab))
      p <- chi2$p.value
    }
    gap <- se_m - it_m
    sig <- if (p < 0.001) "***" else if (p < 0.01) "**" else if (p < 0.05) "*" else ""
    cat(sprintf("    %-20s: IT=%6.2f SE=%6.2f gap=%+6.2f p=%s %s\n",
                spec$label, it_m, se_m, gap, format.pval(p, digits = 3), sig))
    pair_rows[[length(pair_rows)+1]] <- data.frame(
      pair_name = pair$pair_name,
      variable  = spec$label,
      italy     = it_m,
      sweden    = se_m,
      gap_SE_IT = gap,
      p         = p,
      sig       = sig,
      stringsAsFactors = FALSE
    )
  }
}
pair_hc_tab <- do.call(rbind, pair_rows)


# ##############################################################################
# PART F: SALVATAGGIO
# ##############################################################################

cat("\n\n============================================================\n")
cat("SALVATAGGIO RISULTATI\n")
cat("============================================================\n")

saveRDS(italy_compare,
        file.path(data_path, "v9", "outputs", "step11_healthcare_italy_isolati_vs_sociali.rds"))
cat("  Salvato: v9/step11_healthcare_italy_isolati_vs_sociali.rds\n")

saveRDS(cross_tab,
        file.path(data_path, "v9", "outputs", "step11_healthcare_cross_country.rds"))
cat("  Salvato: v9/step11_healthcare_cross_country.rds\n")

saveRDS(pair_hc_tab,
        file.path(data_path, "v9", "outputs", "step11_healthcare_by_pair.rds"))
cat("  Salvato: v9/step11_healthcare_by_pair.rds\n")

# Salva anche i dati italy_hc e sweden_hc arricchiti (utili per analisi
# successive, figure, ecc.)
saveRDS(italy_hc,  file.path(data_path, "v9", "outputs", "step11_italy_with_healthcare.rds"))
saveRDS(sweden_hc, file.path(data_path, "v9", "outputs", "step11_sweden_with_healthcare.rds"))
cat("  Salvato: v9/step11_italy_with_healthcare.rds\n")
cat("  Salvato: v9/step11_sweden_with_healthcare.rds\n")


# ##############################################################################
# RIEPILOGO
# ##############################################################################

cat("\n============================================================\n")
cat("RIEPILOGO STEP 11 — HEALTHCARE\n")
cat("============================================================\n")
cat(sprintf("  Italia: %d righe con healthcare data\n", n_match_it))
cat(sprintf("  Svezia: %d righe con healthcare data\n", n_match_se))
cat("\n  Tabelle prodotte:\n")
cat("    - Moderate Isolated vs Traditional Social (IT, brief line 144-152)\n")
cat("    - Cross-country aggregato (IT vs SE, brief line 155-160)\n")
cat("    - Healthcare gap per matched pair (4 pairs × 6 variabili)\n")

cat("\n============================================================\n")
cat("STEP 11 COMPLETATO.\n")
cat("Pipeline v9/ (Step 1-11) completata. Pronti per scrittura tesi.\n")
cat("============================================================\n")
