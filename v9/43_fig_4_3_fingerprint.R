# ==============================================================================
# FIG 4.3 — Italian profile fingerprints: mean z-score per profile across the
# 29 active analytical variables, grouped by conceptual dimension.
# Adds a profile legend (only dimension headers were present). Lines are the
# per-profile centroids of the deployed standardised data (values unchanged).
# OUTPUT: Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_fingerprint_facet_italy.png
# ==============================================================================
suppressMessages({ library(ggplot2); library(dplyr) })
# ggtext::element_markdown does not render in this environment even when ggtext
# is attached (the literal <span ...> HTML prints through), so we use plain
# black x-axis labels. The coloured dimension headers and the grey alternating
# bands already convey the grouping.
has_ggtext <- FALSE

base <- "/Users/vincenzosilvestri/SHARE_DATASET/DATASET RESEARCH"
prof <- c("Fragile Resigned","Fragile Depressed","Moderate Isolated",
          "Traditional Social","Connected Active")
pal  <- c("Fragile Resigned"="#C8302A","Fragile Depressed"="#E27858",
          "Moderate Isolated"="#888888","Traditional Social"="#4A8FBE",
          "Connected Active"="#143E72")

lab_map <- c(mobility="Mobility limit.", iadl="IADL limitations", adl="ADL limitations",
  sphus="Self-rated health", chronic="Chronic diseases", memory="Memory recall",
  sp002_="Received help", orienti="Orientation",
  eurod="Depression (EURO-D)", casp="Quality of life (CASP)", loneliness="Loneliness",
  interest="Interest in things", hope_future="Hopeful future", expect_alive="Life expectancy",
  ac035d8="Educational course", fluency="Verbal fluency", internet="Internet use",
  fdistress="Financial distress", phinact="Phys. inactive",
  sp008_="Gave help", ac035d5="Volunteering", ac035d1="Sport/club",
  social_integration="Social integration", sn_size_w9="Network size",
  bmi="BMI", log_thinc="Income (log)", ypen1="Pension income",
  log_hnetw="Net wealth (log)", home_own="Home owner")

groups <- list(
  list("Health & Functional", "#A93226", c("mobility","iadl","adl","sphus","chronic","memory","sp002_","orienti")),
  list("Subjective wellbeing", "#2E5A9C", c("eurod","casp","loneliness","interest","hope_future","expect_alive")),
  list("Digital & cognitive",  "#1E8449", c("ac035d8","fluency","internet","fdistress","phinact")),
  list("Social",               "#7D3C98", c("sp008_","ac035d5","ac035d1","social_integration","sn_size_w9")),
  list("Body",                 "#C0399B", c("bmi")),
  list("Economic",             "#CA6F1E", c("log_thinc","ypen1","log_hnetw","home_own")))

var_order <- unlist(lapply(groups, `[[`, 3))
lab_order <- unname(lab_map[var_order])

# --- data: z-scores (step2 std) joined to deployed profiles (step7) ----------
s2 <- readRDS(file.path(base, "v9/outputs/step2_italy_std.rds"))
cl <- readRDS(file.path(base, "v9/outputs/step7_italy_with_clusters.rds"))
prof_by_id <- setNames(as.character(cl$profile), cl$mergeid)
s2$profile <- factor(prof_by_id[s2$mergeid], levels = prof)
s2 <- s2[!is.na(s2$profile), ]

agg <- lapply(var_order, function(v) {
  s2 %>% group_by(profile) %>%
    summarise(m = mean(.data[[v]], na.rm = TRUE),
              se = sd(.data[[v]], na.rm = TRUE) / sqrt(sum(!is.na(.data[[v]]))),
              .groups = "drop") %>%
    mutate(var = v)
}) %>% bind_rows() %>%
  mutate(label = factor(unname(lab_map[var]), levels = lab_order),
         xpos  = as.integer(label))
cat("sanity — mobility & internet centroids:\n")
print(subset(agg, var %in% c("mobility","internet"))[, c("profile","var","m")])

# --- group geometry for shaded bands + headers ------------------------------
ng <- sapply(groups, function(g) length(g[[3]]))
ends <- cumsum(ng); starts <- ends - ng + 1
grp <- data.frame(name = sapply(groups, `[[`, 1), col = sapply(groups, `[[`, 2),
                  xmin = starts - 0.5, xmax = ends + 0.5, ctr = (starts + ends)/2,
                  shade = rep(c(TRUE, FALSE), length.out = length(groups)))
ytop <- max(agg$m + 1.96*agg$se); ybot <- min(agg$m - 1.96*agg$se)
hdr_y <- ytop + 0.30*(ytop - ybot)

# coloured x labels via ggtext if available
if (has_ggtext) {
  lab_cols <- rep(grp$col, ng)
  x_labels <- sprintf("<span style='color:%s'>%s</span>", lab_cols, lab_order)
} else x_labels <- lab_order

p <- ggplot(agg, aes(xpos, m, colour = profile, fill = profile)) +
  geom_rect(data = subset(grp, shade), inherit.aes = FALSE,
            aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = hdr_y),
            fill = "grey95") +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey55", linewidth = 0.3) +
  geom_ribbon(aes(ymin = m - 1.96*se, ymax = m + 1.96*se), colour = NA, alpha = 0.14) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.4) +
  geom_text(data = grp, inherit.aes = FALSE, aes(x = ctr, y = hdr_y, label = name, colour = NULL),
            colour = grp$col, fontface = "bold", size = 4.2, family = "Times", vjust = 0) +
  scale_colour_manual(values = pal, breaks = prof, name = "Profile") +
  scale_fill_manual(values = pal, breaks = prof, guide = "none") +
  scale_x_continuous(breaks = seq_along(lab_order), labels = x_labels,
                     expand = expansion(add = 0.6)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.08))) +
  labs(x = NULL, y = "Mean z-score within Italy") +
  theme_minimal(base_family = "Times", base_size = 12) +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = "right",
        plot.margin = margin(8, 12, 6, 8))

p <- p + theme(axis.text.x = if (has_ggtext)
  ggtext::element_markdown(angle = 45, hjust = 1, size = 9)
  else element_text(angle = 45, hjust = 1, size = 9))

out <- file.path(base, "Invisible_Profiles_LaTeX_Overleaf/figures/04_italy/fig_fingerprint_facet_italy.png")
ggsave(out, p, width = 14, height = 7.2, dpi = 200, bg = "white")
cat("Saved:", out, "  (ggtext:", has_ggtext, ")\n")
