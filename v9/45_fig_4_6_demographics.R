# ==============================================================================
# FIG 4.6 — Profile composition within gender / within age band (100% stacked).
# Adds the column labels (Men/Women; 65-74/75-84/85+) that were missing, and
# keeps the existing profile legend on the age panel. Shares copied verbatim
# from the deployed figures (no recomputation).
# OUTPUT: figures/04_italy/fig_demographics_gender_italy_nolegend.png
#         figures/04_italy/fig_demographics_age_italy.png
# ==============================================================================
suppressMessages({ library(ggplot2); library(dplyr); library(tidyr) })

base <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"
prof <- c("Fragile Resigned","Fragile Depressed","Moderate Isolated",
          "Traditional Social","Connected Active")
pal  <- c("Fragile Resigned"="#C8302A","Fragile Depressed"="#E27858",
          "Moderate Isolated"="#888888","Traditional Social"="#4A8FBE",
          "Connected Active"="#143E72")
# white label on the two dark profiles, dark on the light ones
lab_col <- c("Fragile Resigned"="white","Fragile Depressed"="grey15",
             "Moderate Isolated"="grey15","Traditional Social"="grey15",
             "Connected Active"="white")

# --- deployed shares (% within column), rows = profile order above -----------
gender <- data.frame(
  col = rep(c("Men","Women"), each = 5),
  profile = rep(prof, 2),
  pct = c(9.9,21.7,29.1,11.4,27.8,   16.0,30.8,25.0,4.7,23.4))
age <- data.frame(
  col = rep(c("65–74","75–84","85+"), each = 5),
  profile = rep(prof, 3),
  pct = c(4.1,19.8,36.3,9.2,30.5,  17.2,32.5,19.7,7.3,23.3,  38.2,36.4,11.6,2.9,10.9))

build <- function(df, ylab, col_levels, legend) {
  df$col     <- factor(df$col, levels = col_levels)
  # stack with Fragile Resigned at the bottom, Connected Active at the top
  df$profile <- factor(df$profile, levels = rev(prof))
  df <- df %>% group_by(col) %>% arrange(desc(profile), .by_group = TRUE) %>%
    mutate(ypos = cumsum(pct) - pct/2) %>% ungroup()
  g <- ggplot(df, aes(col, pct/100, fill = profile)) +
    geom_col(width = 0.78, colour = "white", linewidth = 0.6) +
    geom_text(data = subset(df, pct >= 3.5),
              aes(y = ypos/100, label = sprintf("%.1f%%", pct), colour = profile),
              size = 4.4, fontface = "bold", family = "Times") +
    scale_fill_manual(values = pal, breaks = rev(prof), name = "Profile") +
    scale_colour_manual(values = lab_col, guide = "none") +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                       expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, y = ylab) +
    theme_minimal(base_family = "Times", base_size = 14) +
    theme(panel.grid = element_blank(),
          axis.text.x = element_text(size = 14, margin = margin(t = 4)),
          axis.line.x = element_line(colour = "grey30"),
          legend.text = element_text(size = 12),
          plot.margin = margin(10, 12, 8, 8))
  if (!legend) g <- g + guides(fill = "none")
  g
}

g_gender <- build(gender, "Share within gender",  c("Men","Women"), legend = FALSE)
g_age    <- build(age,    "Share within age band", c("65–74","75–84","85+"), legend = TRUE)

og <- file.path(base, "Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_demographics_gender_italy_nolegend.png")
oa <- file.path(base, "Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_demographics_age_italy.png")
ggsave(og, g_gender, width = 8.3, height = 5.0, dpi = 300, bg = "white")
ggsave(oa, g_age,    width = 10.1, height = 5.0, dpi = 300, bg = "white")
cat("Saved:", og, "\n", oa, "\n")
