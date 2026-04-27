# Invisible Profiles — LaTeX project (Overleaf-ready)

Single source of truth for the thesis manuscript. All previous docx/PDF drafts
and parallel builds have been archived under `../_archive_old_pipeline/`.

## How to use on Overleaf

1. Compress this folder into a .zip (you can zip the folder in Finder; the
   contents of `figures/` are ~20 MB so the zip stays well under Overleaf's
   upload cap).
2. Overleaf → New Project → Upload Project → select the .zip.
3. Compiler settings: pdfLaTeX, bibliography = Biber.
4. Click Recompile.

## Project layout

```
Invisible_Profiles_LaTeX_Overleaf/
├── main.tex                      # preamble + \include statements
├── references.bib                # bibliography (APA style, Biber backend)
├── README.md                     # this file
├── chapters/
│   ├── chapter1.tex              # Ageing, digitalisation, invisible vulnerability
│   ├── chapter2.tex              # Literature review
│   ├── chapter3.tex              # Data and methodology (v9-aligned)
│   ├── chapter4.tex              # Italian segmentation
│   ├── chapter5.tex              # Cross-country comparison Italy vs Sweden
│   ├── chapter6.tex              # Robustness and sensitivity
│   ├── chapter7.tex              # Healthcare utilization
│   ├── chapter8.tex              # Implications and conclusions
│   └── appendix.tex              # R code snippets
└── figures/
    ├── 03_data_methods/          # 1 figure (sample flow)
    ├── 04_italy/                 # 13 figures (Italian profiles, diagnostics)
    ├── 05_sweden/                # 12 figures (Swedish profiles, diagnostics)
    ├── 06_comparison/            # 10 figures (cross-country, pooled)
    ├── 07_robustness/            # 12 figures (LCA, method comparisons, SPR²)
    └── 08_appendix/              # 25 figures (detailed diagnostics)
```

Total: 73 PNG + 1 PDF (fig_01 sample flow). Figures are produced by the v9
pipeline under `../v9/` and mirrored here. When the pipeline is re-run and
figures change, sync the folder again:

```bash
cd "<thesis root>"
for sub in 03_data_methods 04_italy 05_sweden 06_comparison 07_robustness 08_appendix; do
  cp v9/figures/$sub/*.{png,pdf} \
     Invisible_Profiles_LaTeX_Overleaf/figures/$sub/ 2>/dev/null
done
```

## Title page metadata (current)

- **Candidate:** Vincenzo Pio Silvestri — student ID 3152937
- **Programme:** MSc Economics and Management of Innovation and Technology (EMIT)
- **Supervisor:** Prof. Trentini
- **Course:** 20570 — Data Analytics and Visualization
- **Academic Year:** 2025–2026

## Status of the chapters

- `chapter3.tex` — **rewritten brand new 2026-04-22** to match the v9 pipeline
  (Italy n = 2,378; Sweden n = 1,787; Mahalanobis p = 0.001 df = 31; clustering
  on standardised original variables; matched-pair Table 3.2; 20 numbered R
  scripts + 2 helper modules).
- `main.tex` — title page refreshed 2026-04-22.
- `chapter6.tex` — overall-sample row in the LCA convergence table updated to
  v9 sample sizes.
- `chapter1.tex`, `chapter2.tex` — no v9-dependent numbers; review recommended
  for narrative flow once the other chapters are finalised.
- `chapter4.tex`, `chapter5.tex`, `chapter7.tex`, `chapter8.tex`, `appendix.tex`
  — **still to be updated to v9 numbers**. Profile-level n, means, cluster-
  quality indexes and healthcare merge rates should be pulled from
  `../v9/outputs/thesis_numbers.md`, which is produced by running
  `../v9/20_thesis_tables.R` from within R.

## Minimum build check before final submission

1. `source("<thesis root>/v9/20_thesis_tables.R")` — regenerates
   `thesis_numbers.md` with the current profile counts and means.
2. Copy the markdown tables into chapters 4, 5, 6, 7.
3. Compile on Overleaf; resolve any missing references or figure paths.
4. Cross-check that every `\ref` points to a real label and every `\cite`
   resolves in the bibliography.
