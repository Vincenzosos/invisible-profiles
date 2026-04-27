# PROJECT KNOWLEDGE BASE — Tesi magistrale Bocconi

> Leggi questo file prima di qualsiasi intervento sulla tesi. È l'unico
> documento che descrive il contesto, la pipeline corrente e le decisioni.

---

## 1. Candidato e progetto

- **Candidato:** Vincenzo Pio Silvestri, matricola 3152937
- **Programma:** MSc Economics and Management of Innovation and Technology (EMIT), Università Bocconi
- **Supervisore:** Prof. Trentini
- **Corso di riferimento:** 20570 — Data Analytics and Visualization, AY 2025
- **Difesa programmata:** luglio 2026
- **Lingua tesi:** inglese accademico
- **Titolo:** *Invisible Profiles: A Multidimensional Segmentation of the Elderly Population in Italy and Sweden Using Objective and Subjective Variables — Evidence from SHARE Wave 9*

---

## 2. La storia in 60 secondi

Segmentare la popolazione over 65 di Italia e Svezia sfruttando SHARE Wave 9
(release 9.0.0). Ogni anziano è descritto da 31 variabili su 5 dimensioni:
salute, risorse economiche, engagement digitale e sociale, funzionamento
cognitivo, percezione soggettiva. L'inclusione della dimensione soggettiva
(CASP-12, loneliness, hope, interest, expect_alive) come **input di
clustering**, non come outcome, è la novità metodologica rispetto alla
letteratura SHARE.

L'ipotesi è che welfare regimes diversi (universalista in Svezia vs
familistico in Italia) producano profili con la stessa struttura ma con
livelli radicalmente diversi, e che in Italia emerga un tipo "Moderate
Isolated" — sano fisicamente ma socialmente isolato — che in Svezia non
esiste. Questo tipo italiano è al centro del Cap 7 perché sottoutilizza il
sistema sanitario in modo misurabile e clinicamente rilevante.

---

## 3. Pipeline analitica (v9)

L'unica pipeline valida è sotto `v9/`. Tutto il materiale pre-v9 è stato
rimosso (o archiviato sul Mac per decisione dell'utente).

**Struttura:**

- 20 script numerati `v9/00_coverage_check.R` → `v9/19_handson_ca_extras.R`
  + `v9/20_thesis_tables.R` (assemblaggio numeri per la tesi)
- 2 helper: `v9/var_labels.R` (dizionario etichette human-readable) e
  `v9/fig_paths.R` (routing delle figure nei sei subfolder per capitolo)
- Output RDS in `v9/outputs/step1..step11_*.rds`
- 73 figure in `v9/figures/` distribuite in
  `03_data_methods/`, `04_italy/`, `05_sweden/`, `06_comparison/`,
  `07_robustness/`, `08_appendix/`

**Dipendenze esterne:** nessuna. La pipeline è self-contained; `psych`,
`cluster`, `poLCA`, `haven`, `tidyverse` via CRAN. `Functions_20570.R` del
corso non è più usato in v9.

---

## 4. Sample e variabili (v9)

### Campioni (coerenti con v9)

| Stadio | Italia | Svezia |
|---|---:|---:|
| SHARE W9 totale | 5.601 | 3.405 |
| Over 65, implicat 1 | 2.399 | 2.202 |
| Dopo listwise (31 var) | 2.378 | 2.045 |
| Outlier Mahalanobis (p = 0.001, df = 31) | 0 | 258 |
| **Campione finale** | **2.378** | **1.787** |

### Le 31 variabili analitiche

- **Salute (8):** sphus, chronic, adl, iadl, mobility, eurod, bmi, phinact
- **Economia (5):** log_thinc, log_hnetw, ypen1, home_own, fdistress
- **Digitale / sociale (10):** internet, ac035d1, ac035d5, ac035d8, sp002_, sp008_, sn_size_w9, social_integration, ac035d4, ac035d7
- **Cognitivo (3):** fluency, memory, orienti
- **Soggettiva (5):** loneliness, casp, hope_future, interest, expect_alive

11 binarie, 20 non-binarie (rank-trasformate). Italia usa 29 variabili
attive nell'analisi (ac035d4 e ac035d7 hanno varianza zero nel campione
italiano e sono escluse dalla PCA/FA italiana).

### Etichette leggibili

Mapping codice-SHARE → testo umano in `v9/var_labels.R`. Usarlo
ovunque compaiano nomi di variabili in figure, tabelle, testo.

---

## 5. Metodologia (v9)

**Preprocessing**
- Rank transform (average-rank) su 20 variabili non-binarie
- Z-standardisation su tutte le 31 variabili
- Outlier: Mahalanobis distance sulle 31 variabili standardizzate, cutoff
  $\chi^2$ a $p = 0.001$ con 31 gradi di libertà. Rimozione effettiva
  (0 casi italiani, 258 casi svedesi)

**Tre approcci complementari**
1. PCA dimension-wise — Kaiser rule con eccezione documentata sui 4 PC del
   blocco Digital/Social
2. Factor Analysis — PA extraction + varimax, 6 factors per paese. KMO
   0.832 IT, 0.808 SE. Heywood case su `social_integration` in Svezia
   (loading 1.11; communality 1.38)
3. LCA — poLCA su variabili binarie + 20 non-binarie discretizzate in
   tertili, k = 2..8, 5 restart, 1000 iter massime

**Clustering finale** — K-means sulle **variabili originali standardizzate**
(non sui PC scores): Italia converge su k = 5, Svezia su k = 6. K-means è
scelto sopra Ward/complete/average linkage sulla base della dominanza
empirica su R² e silhouette (Figure 22–23 / 64–65 / 66–67; Figure 72–73 per
le diagnostiche Duda–Hart).

**Profili attesi** — i nomi sono canonici e **non si rinominano** senza
discussione.

- Italia (5): Fragile Resigned, Fragile Depressed, Moderate Isolated,
  Traditional Social, Connected Active
- Svezia (6): Fragile, Social Decline, Moderate, Asset Rich, Wealthy
  Digital, Connected Wealthy

**Matched-pair mapping cross-country (Cap 5):**

| Matched pair | Italia | Svezia |
|---|---|---|
| Fragile | Fragile Resigned | Fragile |
| Declining | Fragile Depressed | Social Decline |
| Socially-oriented | Traditional Social | Moderate |
| Connected | Connected Active | Connected Wealthy |
| Unmatched | Moderate Isolated | Asset Rich, Wealthy Digital |

I numeri esatti (n per profilo, %, medie sulle variabili chiave, ANOVA
F, gap cross-country, merge rate healthcare) vengono prodotti da
`source("v9/20_thesis_tables.R")` → file `v9/outputs/thesis_numbers.md`.
Qualsiasi tabella per profilo nella tesi deve partire da lì, non da
questo brief.

---

## 6. Struttura della tesi

Fonte unica LaTeX: `Invisible_Profiles_LaTeX_Overleaf/` (pronto per
Overleaf). Docx, PDF compilati e script JS di generazione docx sono stati
rimossi: non esistono più versioni parallele.

| Cap | Titolo | Pagine obiettivo | Stato al 2026-04-22 |
|----:|---|---:|---|
| 1 | Ageing, digitalisation, invisible vulnerability | ~8 | narrativo, nessun numero obsoleto |
| 2 | Literature review | ~10 | nessun numero obsoleto |
| 3 | Data and methodology | ~12 | **riscritto brand new, v9-aligned** |
| 4 | Italian segmentation | ~10 | scheletro brand new, **da riempire con numeri v9** |
| 5 | Cross-country: Italy vs Sweden | ~9 | scheletro brand new, **da riempire con numeri v9** |
| 6 | Robustness and sensitivity | ~7 | scheletro brand new, **da riempire** |
| 7 | Healthcare utilization | ~6 | scheletro brand new, **da riempire con numeri v9** |
| 8 | Implications, proof of concept, conclusions | ~7 | scheletro brand new, **da riempire** |
| App | R code snippets | ~5 | scheletro brand new, **da riempire con codice v9** |

---

## 7. Figure

73 figure PNG generate dalla pipeline, distribuite in sei subfolder per
capitolo sotto `v9/figures/` e specchiate sotto
`Invisible_Profiles_LaTeX_Overleaf/figures/`. La sincronizzazione è
descritta nel README del LaTeX. Ogni figura è etichettata con codici
human-readable via `var_labels.R`.

Le figure "chiave" da tenere a mente nel testo:
- fig_01 — sample flow (Cap 3)
- fig_04/05 — factor loadings IT/SE (Cap 4/5)
- fig_14 — matched-pair gap (Cap 5)
- fig_19–21 — healthcare utilization (Cap 7)
- fig_22/23, 64–67, 72/73 — diagnostiche cluster-quality e Duda–Hart (Cap 6)
- fig_50/51, 70/71 — profile plots canonical (Cap 4/5)

---

## 8. Regole di lavoro

- **Lingua:** tesi in inglese accademico. Chat di lavoro in italiano.
- **Non rinominare i profili** senza discussione esplicita.
- **Non inventare numeri:** qualsiasi valore per profilo passa da
  `v9/20_thesis_tables.R`. Se un numero non è nell'output, non va nel testo.
- **Citazioni corso:** usa "Piccareta & Trentini, 2025" per le dispense
  hands-on del corso 20570. Il 2024 è errato.
- **Font e layout:** Times New Roman 12pt, line spacing 1.3, margini
  Bocconi (left 3.8 cm, right/bottom 2.54 cm, top 3.2 cm), giustificato,
  paragrafi indentati. Già impostato nel `main.tex`.
- **Figure:** nessuna figura "radar" per i profili — l'artefatto di
  `coord_polar` è da evitare.
