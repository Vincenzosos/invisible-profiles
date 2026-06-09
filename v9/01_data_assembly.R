# ==============================================================================
# STEP 1: DATA ASSEMBLY — ITALY
# Thesis: "Beyond the Monolith"
# SHARE Wave 9, Italian 65+, implicat == 1
#
# Questo script:
#   1. Carica i moduli .dta grezzi di SHARE W9
#   2. Filtra Italia, 65+, implicat == 1
#   3. Costruisce tutte le 31 variabili analitiche + variabili ausiliarie
#   4. Verifica tutto con il dataset precedente (share_italy_extended.rds)
#   5. Salva il dataset assemblato
#
# OUTPUT: step1_italy_assembled.rds
# ==============================================================================

# --- 0. SETUP ---------------------------------------------------------------

library(haven)     # read_dta()
library(dplyr)     # data manipulation
library(tidyr)     # pivot/nest if needed

# PATH HARDCODED — cartella dove sono i .dta e i .rds
data_path <- "~/Desktop/SHARE DATASET/DATASET RESEARCH"
cat("Data path:", data_path, "\n")

# Verifica che i file esistano
if (!file.exists(file.path(data_path, "_share_data", "sharew9_rel9-0-0_gv_imputations.dta"))) {
  stop("File .dta non trovati in: ", data_path, "\nControlla il path!")
}
cat("  File .dta trovati — OK\n")

# Helper: legge un modulo SHARE
load_module <- function(module_name) {
  fname <- paste0("sharew9_rel9-0-0_", module_name, ".dta")
  fpath <- file.path(data_path, "_share_data", fname)
  if (!file.exists(fpath)) stop(paste("File non trovato:", fpath))
  cat("  Loading", fname, "...")
  df <- read_dta(fpath)
  cat(" OK (", nrow(df), "rows x", ncol(df), "cols)\n")
  return(df)
}

cat("============================================================\n")
cat("STEP 1: DATA ASSEMBLY — ITALY\n")
cat("============================================================\n\n")


# --- 1. LOAD CORE VARIABLES FROM gv_imputations ----------------------------
# Contiene: variabili health, economic, cognitive e demographic già calcolate.
# SHARE produce 5 implicazioni per i valori mancanti su income/wealth.
# Usiamo implicat == 1 (prima implicazione), come da prassi.
# Country codes: 16 = Italy, 13 = Sweden

cat("--- Loading modules ---\n")
gv_imp <- load_module("gv_imputations")

italy_core <- gv_imp %>%
  filter(country == 16, implicat == 1, age >= 65) %>%
  select(
    mergeid, gender, age,
    # Health (8/8)
    sphus, chronic, adl, iadl, mobility, eurod, bmi, phinact,
    # Economic (5/5 — home_own e fdistress anche da gv_imputations!)
    thinc, hnetw, ypen1, home, fdistress,
    # Digital (1/10)
    internet,
    # Cognitive (3/3)
    fluency, memory, orienti
  ) %>%
  mutate(
    # HOME OWNERSHIP: derivata da home value in gv_imputations
    # home > 0 = owner (1), home == 0 = non-owner (0)
    # Verificato: 2399/2399 exact match con dataset precedente, 0 NAs
    home_own = ifelse(home > 0, 1, 0),
    # FINANCIAL DISTRESS: già in gv_imputations (1-4 scale)
    # Solo 9 valori = -99 (special code) → NA
    fdistress = ifelse(fdistress < 0, NA_real_, fdistress)
  ) %>%
  select(-home)  # rimuovi home value, teniamo solo home_own

cat("  Italy 65+ implicat==1:", nrow(italy_core), "rows\n\n")


# --- 2. SOCIAL NETWORKS (sn_size_w9, social_integration) --------------------
# Source: gv_networks — variabili generate da SHARE sul social network
# sn_size_w9: numero di persone nella rete sociale (1-7)
# social_integration: indice di integrazione sociale (1-4, high = more integrated)

gv_net <- load_module("gv_networks")

networks <- gv_net %>%
  filter(country == 16) %>%
  select(mergeid, sn_size_w9, social_integration) %>%
  mutate(
    # Valori negativi in SHARE = codici speciali (-1=don't know, -2=refusal, etc.)
    sn_size_w9       = ifelse(sn_size_w9 < 0, NA_real_, sn_size_w9),
    social_integration = ifelse(social_integration < 0, NA_real_, social_integration)
  )


# --- 3. ACTIVITIES (ac035d1, d4, d5, d7, d8) + CASP-12 ---------------------
# Source: ac module
# ac035d* = attività svolte nell'ultimo mese (binarie: 1=sì, 0=no)
#   d1 = voluntary/charity work
#   d4 = attended educational course
#   d5 = sport/social club
#   d7 = taken part in political organization
#   d8 = read books/magazines
# CASP-12: quality of life scale (ac014_-ac025_)
#   12 items, ciascuno 1-4. Alcuni vanno reverse-scored.
#   Range totale: 12 (peggiore) - 48 (migliore)

ac <- load_module("ac")

activities <- ac %>%
  filter(country == 16) %>%
  select(
    mergeid,
    ac035d1, ac035d4, ac035d5, ac035d7, ac035d8,
    ac014_, ac015_, ac016_, ac017_, ac018_, ac019_,
    ac020_, ac021_, ac022_, ac023_, ac024_, ac025_
  ) %>%
  # Negativi → NA
  mutate(across(-mergeid, ~ ifelse(. < 0, NA_real_, .)))

# CASP-12 scoring
# In SHARE W9, le risposte sono: 1=Often, 2=Sometimes, 3=Not often, 4=Never
#
# ATTENZIONE: la scala 1-4 va letta così:
#   Per items NEGATIVI (es. "Age prevents me"), 4=Never = buona QoL → GIÀ corretto
#   Per items POSITIVI (es. "I look forward to each day"), 1=Often = buona QoL → VA REVERSED
#
# Items NEGATIVI (NO reverse — raw score già corretto, 4=Never=buono):
#   ac014_ "Age prevents me from doing things"
#   ac015_ "I feel out of control"
#   ac016_ "I feel left out of things"
#   ac018_ "Family responsibilities prevent me"
#   ac019_ "Shortage of money stops me"
#
# Items POSITIVI (VANNO REVERSED — 1=Often=buono deve diventare 4):
#   ac017_ "I can do the things I want"
#   ac020_ "I look forward to each day"
#   ac021_ "I feel that my life has meaning"
#   ac022_ "I look back on life with happiness"
#   ac023_ "I feel full of energy"
#   ac024_ "I feel satisfied with my life"
#   ac025_ "Future looks good"
#
# Reverse: new = 5 - old. Range totale: 12 (peggiore) - 48 (migliore)
# VERIFICATO: 2364/2364 exact match con dataset precedente

activities <- activities %>%
  mutate(
    casp = ac014_ + ac015_ + ac016_ +
           (5 - ac017_) +
           ac018_ + ac019_ +
           (5 - ac020_) + (5 - ac021_) + (5 - ac022_) +
           (5 - ac023_) + (5 - ac024_) + (5 - ac025_)
  ) %>%
  select(mergeid, ac035d1, ac035d4, ac035d5, ac035d7, ac035d8, casp)


# --- 4. SOCIAL PARTICIPATION (sp002_, sp008_) --------------------------------
# Source: sp module
# sp002_ "Received help from others outside household": 1=Yes, 5=No
# sp008_ "Given help to others in last 12 months": 1=Yes, 5=No
# Recode: 1→1 (sì), 5→0 (no)

sp <- load_module("sp")

social_part <- sp %>%
  filter(country == 16) %>%
  select(mergeid, sp002_, sp008_) %>%
  mutate(
    sp002_ = case_when(sp002_ == 1 ~ 1, sp002_ == 5 ~ 0, TRUE ~ NA_real_),
    sp008_ = case_when(sp008_ == 1 ~ 1, sp008_ == 5 ~ 0, TRUE ~ NA_real_)
  )


# --- 5. MENTAL HEALTH (loneliness, hope_future, interest) --------------------
# Source: mh module
#
# LONELINESS: R-UCLA 3-item scale (reversed per coerenza con dataset precedente)
#   mh035_ "How often do you feel left out?"
#   mh036_ "How often do you feel isolated?"
#   mh037_ "How often do you feel lonely?"
#   Raw coding SHARE: 1=Hardly ever, 2=Some of the time, 3=Often
#   Reversed: (4 - item) → 3=Hardly ever, 2=Some, 1=Often
#   Sum range: 3 (massima solitudine) - 9 (minima solitudine)
#   NOTA: il dataset precedente usava questa scala reversed.
#   Verifica: 1848/2382 exact match (78% — differenze minori da data cleaning)
#
# HOPE_FUTURE: from EURO-D depression scale
#   mh003_ "What are your hopes for the future?"
#   1 = Has hopes for the future (non depresso)
#   2 = No hopes
#   → Recode: 1→1, 2→0
#
# INTEREST: from EURO-D
#   mh008_ "In the last month, what is your interest in things?"
#   1 = Less interest than usual
#   2 = Same as usual
#   3 = More interest than usual
#   → Scala diretta 1-3 (higher = more interest = better)
#   NOTA: il dataset precedente escludeva mh008_==1 e usava scala 3-4.
#   Noi usiamo scala 1-3 completa per preservare il campione (20% in meno altrimenti).
#   La rank transformation a valle gestirà la natura ordinale.

mh <- load_module("mh")

mental <- mh %>%
  filter(country == 16) %>%
  select(mergeid, mh003_, mh008_, mh035_, mh036_, mh037_) %>%
  mutate(across(-mergeid, ~ ifelse(. < 0, NA_real_, .))) %>%
  mutate(
    # Loneliness reversed: high = less lonely (coerente con dataset precedente)
    loneliness  = (4 - mh035_) + (4 - mh036_) + (4 - mh037_),
    hope_future = case_when(mh003_ == 1 ~ 1, mh003_ == 2 ~ 0, TRUE ~ NA_real_),
    # Interest: scala diretta 1-3 da mh008_ (higher = more interest)
    interest    = ifelse(mh008_ %in% c(1, 2, 3), mh008_, NA_real_)
  ) %>%
  select(mergeid, loneliness, hope_future, interest)


# --- 6. HOME OWNERSHIP & FINANCIAL DISTRESS -----------------------------------
# ENTRAMBI ora estratti da gv_imputations (Step 1, italy_core) — NON servono
# ho e co modules. gv_imputations ha copertura completa (0 NAs per home_own,
# solo 9 NAs per fdistress) vs ho/co modules che avevano 36% missing.
# Verificato: home_own da gv_imputations → 2399/2399 exact match con dataset
# precedente.


# --- 7. LIFE EXPECTANCY EXPECTATIONS -----------------------------------------
# Source: ex module
# ex009_ "What are the chances you will live to be [target age]?"
#   Scala 0-100 (percentuale)

ex <- load_module("ex")

expectations <- ex %>%
  filter(country == 16) %>%
  select(mergeid, ex009_) %>%
  mutate(
    expect_alive = ifelse(ex009_ < 0, NA_real_, ex009_)
  ) %>%
  select(mergeid, expect_alive)


# ==============================================================================
# 3. MERGE ALL MODULES
# ==============================================================================

cat("\n--- Merging all modules ---\n")

# NOTA: home_own e fdistress già in italy_core (da gv_imputations)
italy <- italy_core %>%
  left_join(networks,     by = "mergeid") %>%
  left_join(activities,   by = "mergeid") %>%
  left_join(social_part,  by = "mergeid") %>%
  left_join(mental,       by = "mergeid") %>%
  left_join(expectations, by = "mergeid")

cat("  After merge:", nrow(italy), "rows x", ncol(italy), "cols\n")


# ==============================================================================
# 4. CONSTRUCT DERIVED VARIABLES
# ==============================================================================

italy <- italy %>%
  mutate(
    # Log-transformazioni per income e wealth
    # +1 per gestire gli zeri; pmax(., 0) per gestire i patrimoni negativi
    log_thinc = log(pmax(thinc, 0) + 1),
    log_hnetw = log(pmax(hnetw, 0) + 1)
  )


# ==============================================================================
# 5. VERIFICA: MISSING PER VARIABILE
# ==============================================================================

cat("\n--- Missing analysis ---\n")

# Le 31 variabili analitiche
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
  n_miss <- sum(is.na(italy[[v]]))
  n_val  <- sum(!is.na(italy[[v]]))
  pct    <- 100 * n_miss / nrow(italy)
  cat(sprintf("%-22s | %7d | %9d | %6.1f%%\n", v, n_val, n_miss, pct))
}

cat("\n  N totale:", nrow(italy))
cat("\n  N con tutte 31 complete:", sum(complete.cases(italy[, all_31])), "\n")


# ==============================================================================
# 6. VERIFICA: CONFRONTO CON DATASET PRECEDENTE
# ==============================================================================
# Carica il dataset esistente per confrontare i numeri.
# Se non lo hai, commenta questa sezione.

cat("\n--- Confronto con dataset precedente ---\n")

old_file <- file.path(data_path, "share_italy_extended.rds")
if (file.exists(old_file)) {
  old <- readRDS(old_file)
  cat("  Dataset precedente:", nrow(old), "rows x", ncol(old), "cols\n")

  # Confronta le distribuzioni delle variabili chiave
  # Merge per mergeid per confronto 1:1
  comparison <- italy %>%
    inner_join(old %>% select(mergeid, any_of(all_31)), by = "mergeid", suffix = c("_new", "_old"))

  cat("  Righe in comune:", nrow(comparison), "\n\n")

  # Confronta media e SD per ogni variabile
  cat("Variabile              | Media NEW | Media OLD | Diff   | Match?\n")
  cat("----------------------------------------------------------------\n")
  for (v in all_31) {
    v_new <- paste0(v, "_new")
    v_old <- paste0(v, "_old")
    if (v_new %in% names(comparison) && v_old %in% names(comparison)) {
      m_new <- mean(comparison[[v_new]], na.rm = TRUE)
      m_old <- mean(comparison[[v_old]], na.rm = TRUE)
      diff  <- abs(m_new - m_old)
      match <- ifelse(diff < 0.01, "OK", "VERIFICA!")
      cat(sprintf("%-22s | %9.3f | %9.3f | %6.3f | %s\n", v, m_new, m_old, diff, match))
    }
  }
} else {
  cat("  File share_italy_extended.rds non trovato — skip confronto.\n")
}


# ==============================================================================
# 7. SALVA
# ==============================================================================

# Dataset completo (prima di listwise deletion)
saveRDS(italy, file.path(data_path, "v9", "outputs", "step1_italy_assembled.rds"))
cat("\n  Salvato: v9/step1_italy_assembled.rds\n")

# Anche un CSV per ispezione rapida
write.csv(italy[1:20, c("mergeid", "age", "gender", all_31)],
          file.path(data_path, "v9", "outputs", "step1_preview.csv"),
          row.names = FALSE)
cat("  Salvato: v9/step1_preview.csv (prime 20 righe)\n")

cat("\n============================================================\n")
cat("STEP 1 COMPLETATO.\n")
cat("Prossimo step: listwise deletion + outlier check (Step 2)\n")
cat("============================================================\n")
