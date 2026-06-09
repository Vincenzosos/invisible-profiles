## strip_figure_labs.R
## ---------------------------------------------------------------------------
## Removes the baked-in title / subtitle / caption from EVERY figure saved with
## ggsave(), so the only caption a figure carries is the LaTeX \caption in the
## thesis. This avoids the "double caption" (grey text inside the PNG + the
## numbered LaTeX caption below it).
##
## HOW IT WORKS
##   It redefines ggsave() in the global environment with a thin wrapper that,
##   just before saving, appends:
##       + labs(title = NULL, subtitle = NULL, caption = NULL)
##       + theme(plot.title/subtitle/caption = element_blank())
##   Because these are added LAST, they override whatever each script set
##   earlier, regardless of the theme used (theme_thesis, theme_minimal, ...).
##   It touches ONLY plot title/subtitle/caption — axis titles, legends, and
##   facet strip labels (e.g. "Italy" / "Sweden") are left untouched.
##
## USAGE
##   Source THIS file first, then re-run your figure scripts in the SAME R
##   session so the wrapper is in effect when they call ggsave():
##
##       source("v9/strip_figure_labs.R")
##       source("v9/12_figures.R")
##       source("v9/25_chapter5_figures.R")
##       source("v9/26_chapter5_thematic_figures.R")
##       source("v9/27_fix_fig_4_2_shares.R")
##       source("v9/37_fig_3_3_loadings.R")
##       source("v9/38_fig_mahalanobis.R")
##       source("v9/39_fix_figures_p6.R")
##       ## ...and any other figure script (13, 14, 15, ...) you use.
##
##   (If you have an orchestrator such as make_thesis_figures.R that sources the
##    figure scripts, just source THIS file first, then source that.)
##
##   To restore the normal ggsave() afterwards:  rm(ggsave)
## ---------------------------------------------------------------------------

library(ggplot2)

## keep a single pristine copy of the real ggsave
if (!exists(".orig_ggsave_thesis")) {
  .orig_ggsave_thesis <- ggplot2::ggsave
}

ggsave <- function(filename, plot = ggplot2::last_plot(), ...) {
  if (inherits(plot, "ggplot")) {
    plot <- plot +
      ggplot2::labs(title = NULL, subtitle = NULL, caption = NULL) +
      ggplot2::theme(
        plot.title    = ggplot2::element_blank(),
        plot.subtitle = ggplot2::element_blank(),
        plot.caption  = ggplot2::element_blank()
      )
  }
  .orig_ggsave_thesis(filename = filename, plot = plot, ...)
}

message("strip_figure_labs.R loaded: ggsave() will now drop plot title/subtitle/caption.")
