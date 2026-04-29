# ==============================================================================
# STEP 3: DATA ASSEMBLY — SWEDEN
# Thesis: "Beyond the Monolith"
# SHARE Wave 9, Swedish 65+, implicat == 1
#
# Identico a Step 1 ma con country == 13 (Sweden).
# Stesse 31 variabili, stessa costruzione, stessi moduli.
#
# OUTPUT: v9/step3_sweden_w8_assembled.rds
# ==============================================================================

# --- 0. SETUP ---------------------------------------------------------------

library(haven)
library(dplyr)
library(tidyr)

data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
cat("Data path:", data_path, "\n")

if (!file.exists(file.path(data_path, "sharew8_rel9-0-0_gv_imputations.dta"))) {
  stop("File .dta non trovati in: ", data_path, "\nControlla il path!")
}
cat("  File .dta trovati — OK\n")

load_module <- function(module_name) {
  fname <- paste0("sharew8_rel9-0-0_", module_name, ".dta")
  fpath <- file.path(data_path, fname)
  if (!file.exists(fpath)) stop(paste("File non trovato:", fpath))
  cat("  Loading", fname, "...")
  df <- read_dta(fpath)
  cat(" OK (", nrow(df), "rows x", ncol(df), "cols)\n")
  return(df)
}

cat("============================================================\n")
cat("STEP 3: DATA ASSEMBLY — SWEDEN\n")
cat("============================================================\n\n")


# --- 1. LOAD CORE VARIABLES FROM gv_imputations ----------------------------
# Country code: 13 = Sweden

cat("--- Loading modules ---\n")
gv_imp <- load_module("gv_imputations")

sweden_core <- gv_imp %>%
  filter(country == 13, implicat == 1, age >= 65) %>%
  select(
    mergeid, gender, age,
    sphus, chronic, adl, iadl, mobility, eurod, bmi, phinact,
    thinc, hnetw, ypen1, home, fdistress,
    internet,
    fluency, memory, orienti
  ) %>%
  mutate(
    home_own  = ifelse(home > 0, 1, 0),
    fdistress = ifelse(fdistress < 0, NA_real_, fdistress)
  ) %>%
  select(-home)

cat("  Sweden 65+ implicat==1:", nrow(sweden_core), "rows\n\n")


# --- 2. SOCIAL NETWORKS -----------------------------------------------------

gv_net <- load_module("gv_networks")

networks <- gv_net %>%
  filter(country == 13) %>%
  rename(sn_size_w9 = sn_size_w8) %>%
  select(mergeid, sn_size_w9, social_integration) %>%
  mutate(
    sn_size_w9         = ifelse(sn_size_w9 < 0, NA_real_, sn_size_w9),
    social_integration = ifelse(social_integration < 0, NA_real_, social_integration)
  )


# --- 3. ACTIVITIES + CASP-12 ------------------------------------------------

ac <- load_module("ac")

activities <- ac %>%
  filter(country == 13) %>%
  select(
    mergeid,
    ac035d1, ac035d4, ac035d5, ac035d7, ac035d8,
    ac014_, ac015_, ac016_, ac017_, ac018_, ac019_,
    ac020_, ac021_, ac022_, ac023_, ac024_, ac025_
  ) %>%
  mutate(across(-mergeid, ~ ifelse(. < 0, NA_real_, .)))

# CASP-12: reverse POSITIVE items (stessa logica di Step 1 Italia)
activities <- activities %>%
  mutate(
    casp = ac014_ + ac015_ + ac016_ +
           (5 - ac017_) +
           ac018_ + ac019_ +
           (5 - ac020_) + (5 - ac021_) + (5 - ac022_) +
           (5 - ac023_) + (5 - ac024_) + (5 - ac025_)
  ) %>%
  select(mergeid, ac035d1, ac035d4, ac035d5, ac035d7, ac035d8, casp)


# --- 4. SOCIAL PARTICIPATION ------------------------------------------------

sp <- load_module("sp")

social_part <- sp %>%
  filter(country == 13) %>%
  select(mergeid, sp002_, sp008_) %>%
  mutate(
    sp002_ = case_when(sp002_ == 1 ~ 1, sp002_ == 5 ~ 0, TRUE ~ NA_real_),
    sp008_ = case_when(sp008_ == 1 ~ 1, sp008_ == 5 ~ 0, TRUE ~ NA_real_)
  )


# --- 5. MENTAL HEALTH -------------------------------------------------------

mh <- load_module("mh")

mental <- mh %>%
  filter(country == 13) %>%
  select(mergeid, mh003_, mh008_, mh035_, mh036_, mh037_) %>%
  mutate(across(-mergeid, ~ ifelse(. < 0, NA_real_, .))) %>%
  mutate(
    loneliness  = (4 - mh035_) + (4 - mh036_) + (4 - mh037_),
    hope_future = case_when(mh003_ == 1 ~ 1, mh003_ == 2 ~ 0, TRUE ~ NA_real_),
    interest    = ifelse(mh008_ %in% c(1, 2, 3), mh008_, NA_real_)
  ) %>%
  select(mergeid, loneliness, hope_future, interest)


# --- 6. HOME OWNERSHIP & FINANCIAL DISTRESS ----------------------------------
# Già in sweden_core da gv_imputations.


# --- 7. LIFE EXPECTANCY EXPECTATIONS ----------------------------------------

ex <- load_module("ex")

expectations <- ex %>%
  filter(country == 13) %>%
  select(mergeid, ex009_) %>%
  mutate(
    expect_alive = ifelse(ex009_ < 0, NA_real_, ex009_)
  ) %>%
  select(mergeid, expect_alive)


# ==============================================================================
# MERGE ALL MODULES
# ==============================================================================

cat("\n--- Merging all modules ---\n")

sweden <- sweden_core %>%
  left_join(networks,     by = "mergeid") %>%
  left_join(activities,   by = "mergeid") %>%
  left_join(social_part,  by = "mergeid") %>%
  left_join(mental,       by = "mergeid") %>%
  left_join(expectations, by = "mergeid")

cat("  After merge:", nrow(sweden), "rows x", ncol(sweden), "cols\n")


# ==============================================================================
# CONSTRUCT DERIVED VARIABLES
# ==============================================================================

sweden <- sweden %>%
  mutate(
    log_thinc = log(pmax(thinc, 0) + 1),
    log_hnetw = log(pmax(hnetw, 0) + 1)
  )


# ==============================================================================
# MISSING ANALYSIS
# ==============================================================================

cat("\n--- Missing analysis ---\n")

health_vars  <- c("sphus", "chronic", "adl", "iadl", "mobility", "eurod", "bmi", "phinact")
econ_vars    <- c("log_thinc", "log_hnetw", "ypen1", "home_own", "fdistress")
digital_vars <- c("internet", "ac035d1", "ac035d5", "ac035d8",
                   "sp002_", "sp008_", "sn_size_w9", "social_integration",
                   "ac035d4", "ac035d7")
cog_vars     <- c("fluency", "memory", "orienti")
subj_vars    <- c("loneliness", "casp", "hope_future", "interest", "expect_alive")

all_31 <- c(health_vars, econ_vars, digital_vars, cog_vars, subj_vars)

cat("\nVariabile              | N validi | N missing | % missing\n")
cat("------------------------------------------------------------\n")
for (v in all_31) {
  n_miss <- sum(is.na(sweden[[v]]))
  n_val  <- sum(!is.na(sweden[[v]]))
  pct    <- 100 * n_miss / nrow(sweden)
  cat(sprintf("%-22s | %7d | %9d | %6.1f%%\n", v, n_val, n_miss, pct))
}

cat("\n  N totale:", nrow(sweden))
cat("\n  N con tutte 31 complete:", sum(complete.cases(sweden[, all_31])), "\n")


# ==============================================================================
# SALVA
# ==============================================================================

saveRDS(sweden, file.path(data_path, "v9", "outputs", "step3_sweden_w8_assembled.rds"))
cat("\n  Salvato: v9/step3_sweden_w8_assembled.rds\n")

write.csv(sweden[1:20, c("mergeid", "age", "gender", all_31)],
          file.path(data_path, "v9", "outputs", "step3_preview.csv"),
          row.names = FALSE)
cat("  Salvato: v9/step3_preview.csv (prime 20 righe)\n")

cat("\n============================================================\n")
cat("STEP 3 COMPLETATO.\n")
cat("Prossimo step: listwise deletion + outlier Sweden (Step 4)\n")
cat("============================================================\n")
