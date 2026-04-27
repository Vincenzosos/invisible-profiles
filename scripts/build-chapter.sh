#!/usr/bin/env bash
# Build a single chapter of the thesis as a standalone PDF.
#
# Usage: scripts/build-chapter.sh <N|appendix>
#   N: chapter number 1..8
#   "appendix" for the appendix
#
# Output: Trentini_submission/Chapter_<N>.pdf  (or Chapter_appendix.pdf)

set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <N|appendix>" >&2
  echo "  N: chapter number 1..8" >&2
  exit 2
fi

ARG="$1"
case "$ARG" in
  appendix)
    CHAPTER_BASE="appendix"
    OUT_NAME="Chapter_appendix.pdf"
    SET_COUNTER=""
    PRE_INCLUDE='\appendix'
    ;;
  [1-8])
    CHAPTER_BASE="chapter${ARG}"
    OUT_NAME="Chapter_${ARG}.pdf"
    SET_COUNTER="\\setcounter{chapter}{$((ARG-1))}"
    PRE_INCLUDE=""
    ;;
  *)
    echo "Error: argument must be 1..8 or 'appendix' (got '$ARG')" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LATEX_DIR="$ROOT/Invisible_Profiles_LaTeX_Overleaf"
SUB_DIR="$ROOT/Trentini_submission"
MAIN_TEX="$LATEX_DIR/main.tex"
CHAPTER_TEX="$LATEX_DIR/chapters/${CHAPTER_BASE}.tex"

if [[ ! -f "$MAIN_TEX" ]]; then
  echo "Error: $MAIN_TEX not found" >&2; exit 1
fi
if [[ ! -f "$CHAPTER_TEX" ]]; then
  echo "Error: $CHAPTER_TEX not found" >&2; exit 1
fi
mkdir -p "$SUB_DIR"

WRAPPER_BASE="_chapter_${ARG}_wrapper"
WRAPPER_TEX="$LATEX_DIR/${WRAPPER_BASE}.tex"

# Extract preamble (everything before \begin{document}) from main.tex.
PREAMBLE=$(awk '/\\begin\{document\}/{exit} {print}' "$MAIN_TEX")

{
  printf '%s\n' "$PREAMBLE"
  echo '\begin{document}'
  [[ -n "$PRE_INCLUDE"  ]] && echo "$PRE_INCLUDE"
  [[ -n "$SET_COUNTER"  ]] && echo "$SET_COUNTER"
  echo "\\include{chapters/${CHAPTER_BASE}}"
  echo '\printbibliography[heading=bibintoc, title={Bibliography}]'
  echo '\end{document}'
} > "$WRAPPER_TEX"

cd "$LATEX_DIR"

echo ">> pdflatex (pass 1)"
pdflatex -interaction=nonstopmode "${WRAPPER_BASE}.tex" >/dev/null
echo ">> biber"
biber "${WRAPPER_BASE}" >/dev/null
echo ">> pdflatex (pass 2)"
pdflatex -interaction=nonstopmode "${WRAPPER_BASE}.tex" >/dev/null
echo ">> pdflatex (pass 3)"
pdflatex -interaction=nonstopmode "${WRAPPER_BASE}.tex" >/dev/null

if [[ ! -f "${WRAPPER_BASE}.pdf" ]]; then
  echo "Error: PDF was not produced. See ${LATEX_DIR}/${WRAPPER_BASE}.log" >&2
  exit 1
fi

mv "${WRAPPER_BASE}.pdf" "$SUB_DIR/${OUT_NAME}"

# Clean intermediate files (wrapper + sibling .aux from \include).
rm -f "${WRAPPER_TEX}"
for ext in aux log out toc bbl bcf blg run.xml lof lot fls fdb_latexmk synctex.gz; do
  rm -f "${WRAPPER_BASE}.${ext}"
done
rm -f "chapters/${CHAPTER_BASE}.aux"

echo "Built: $SUB_DIR/${OUT_NAME}"
