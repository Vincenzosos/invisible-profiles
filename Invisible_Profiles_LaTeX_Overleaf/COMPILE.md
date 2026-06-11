# Compile the thesis (terminal / Claude Code)

## One-liner with latexmk (recommended)

```bash
cd Invisible_Profiles_LaTeX_Overleaf
latexmk -pdf main.tex
```

`latexmk` automatically runs pdflatex and biber the right number of times.

## Manual sequence (if latexmk unavailable)

```bash
cd Invisible_Profiles_LaTeX_Overleaf
pdflatex main.tex      # first pass — generates .aux files
biber main             # processes references.bib
pdflatex main.tex      # second pass — resolves citations
pdflatex main.tex      # third pass — resolves cross-references
```

Output: `main.pdf`

## Required tools

- **TeX Live 2022+** (provides pdflatex)
- **biber** (bibliography processor — comes with TeX Live)
- **biblatex** package (comes with TeX Live)
- **latexmk** (optional but recommended — comes with TeX Live)

Verify with:
```bash
pdflatex --version && biber --version && latexmk --version
```

If any are missing on macOS, install via:
```bash
brew install --cask mactex
```

## Cleanup auxiliary files

After successful compilation, you can clean intermediate files:
```bash
latexmk -c   # remove aux/log/toc/bcf, keep main.pdf
latexmk -C   # remove EVERYTHING auxiliary AND main.pdf
```

## Project structure

```
Invisible_Profiles_LaTeX_Overleaf/
├── main.tex                    # Document orchestrator
├── references.bib              # Bibliography database
├── chapters/
│   ├── chapter1.tex            # Introduction
│   ├── chapter2.tex            # Literature review
│   ├── chapter3.tex            # Methodology    ← FINAL (rewritten from DOCX)
│   ├── chapter4.tex            # Italian Typology ← FINAL (rewritten from DOCX)
│   ├── chapter5.tex            # Sweden
│   ├── chapter6.tex            # Comparison
│   ├── chapter7.tex            # Robustness
│   ├── chapter8.tex            # Conclusions
│   ├── appendix.tex            # Appendices
│   ├── chapter3_OLD.tex.bak    # Backup of pre-rewrite cap 3
│   └── chapter4_OLD.tex.bak    # Backup of pre-rewrite cap 4
└── figures/
    ├── 03_data_methods/        # Cap 3 figures
    ├── 04_italy/                # Cap 4 figures
    ├── 05_sweden/               # Cap 5 figures
    ├── 06_comparison/           # Cap 6 figures
    ├── 07_robustness/           # Cap 7 figures
    └── 08_appendix/             # Appendix figures
```

## Recent changes (2026-04-30 / 2026-05-01)

- Cap 3 and Cap 4 rewritten from FINAL DOCX with biblatex `\citep{}` citations
- 26 new bibliography entries added to `references.bib` (all verified: berkman2000, hartigan1979, hyde2003, quan2017, hawkley2010, rowe1997, vermunt2002, and 19 others)
- Figures regenerated with Editorial duotone palette (Fragile Resigned `#B0413A`, etc.)
- Fig 3.3 reconstructed with semantically-renamed factors (Physical / Subjective / Cultural / Social / Income / Wealth)
- Fig 4.7 (Healthcare under-utilisation) NOT YET ADDED — pending decision on Isolation Paradox narrative reformulation
- Fig 4.8 (Population shares) added at end of §4.8
- references_to_add.bib kept as a reference staging file (all entries already merged into references.bib)

## Backups

If anything in the new `chapter3.tex` or `chapter4.tex` looks wrong:
```bash
cp chapters/chapter3_OLD.tex.bak chapters/chapter3.tex
cp chapters/chapter4_OLD.tex.bak chapters/chapter4.tex
```
This restores the pre-rewrite versions.

## Verification checklist

Before submission:
- [ ] `latexmk -pdf main.tex` completes without errors
- [ ] `main.pdf` opens and has all chapters
- [ ] All citations resolve (no `[?]` placeholders)
- [ ] Figures in cap 3 and 4 are the Editorial duotone versions
- [ ] Cross-references to chapters/sections are correct
