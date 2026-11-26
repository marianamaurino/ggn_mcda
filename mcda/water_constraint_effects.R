# Effect of the water constraint (spec 1.3, decided 25 November 2026) on both scores. Water cells = majority Urban
# Atlas class 50000 (Malta Urban Atlas 2021, Klagenfurt Urban Atlas 2018), not eligible for greening, not scored and
# excluded from every normalisation bound (in Malta the airport and port cells are now also excluded from every bound).
# Old = *_pre_water.rds backups, new = the main score files. Instruction: mcda/Water_constraint_instructions.Rmd,
# steps 2 and 5. Outputs: output/figures_mcda/water_constraint_2026_11_25/ (tables as CSV, figures as PDF, SVG, PNG).
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 \
#      nice -n 10 Rscript mcda/water_constraint_effects.R

suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(sf); library(purrr); library(ggplot2); library(patchwork) })
source(here::here("R/theme_lancet.R"))
sf_use_s2(FALSE)
OUT <- here::here("output/figures_mcda/water_constraint_2026_11_25")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
lw_pt <- function(pt) pt / (ggplot2::.pt * 0.75)
save_fig <- function(p, name, h, w = 180) invisible(save_figure_lancet(p, name, OUT, height_mm = h, width_mm = w))
show <- function(x, nm) {
  cat("\n==", nm, "\n"); print(as.data.frame(mutate(x, across(where(is.double), ~ round(., 3)))), row.names = FALSE)
  readr::write_csv(x, file.path(OUT, paste0(nm, ".csv")))
}
city_cols <- c(Malta = "#2166ac", Klagenfurt = "#b2182b")
score_cols <- c(Old = "grey60", New = "black")

# ---- Data -------------------------------------------------------------------------------------
read_city <- function(cn) {
  if (cn == "Malta") {
    old <- readRDS(here::here("data/malta/malta_mcda_processed_realloc_pre_water.rds"))
    new <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds"))
    stopifnot(nrow(old) == 10657, nrow(new) == 10657, identical(as.character(old$gid), as.character(new$gid)))
    unit <- new$NAME; pop <- new$Total_Population
    old_mask <- old$ua_not_eligible
  } else {
    old <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may_pre_water.rds"))
    new <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds"))
    stopifnot(nrow(old) == 12418, nrow(new) == 12418, identical(old$ID, new$ID))
    zsp <- st_read(here::here("data/klagenfurt/klagenfurt_zsp_aest.gpkg"), quiet = TRUE) %>% st_transform(st_crs(new))
    unit <- as.character(zsp$g_id[sapply(st_intersects(st_centroid(st_geometry(new)), zsp), function(i) if (length(i)) i[1] else NA)])
    pop <- new$popdense_2020
    old_mask <- rep(FALSE, nrow(old))
  }
  list(old = old, new = new, unit = unit, pop = pop, old_mask = old_mask, new_mask = new$ua_not_eligible,
       water = new$water_cell, water_share = new$water_share_ua)
}
D <- list(Malta = read_city("Malta"), Klagenfurt = read_city("Klagenfurt"))
top_q <- function(p) { q <- rep(NA_integer_, length(p)); q[!is.na(p)] <- ntile(p[!is.na(p)], 5); q }
pair <- function(a, b) {
  qa <- top_q(a); qb <- top_q(b); k <- !is.na(a) & !is.na(b)
  tibble(cells_scored_in_both = sum(k), spearman = cor(a[k], b[k], method = "spearman"),
         top_quintile_overlap_pct = 100 * sum(qa == 5 & qb == 5 & k) / sum(qa == 5 & k),
         cells_changing_quintile_pct = 100 * mean(qa[k] != qb[k]))
}
areas <- list(Malta = st_sf(geometry = readRDS(here::here("data/malta/malta_union_boundary.rds")), crs = 3035),
              Klagenfurt = readRDS(here::here("data/klagenfurt/klagenfurt_boundary.rds")) %>% st_transform(3035) %>% st_union() %>% st_sf(geometry = .))
ras <- function(g) {
  xy <- st_coordinates(st_centroid(st_geometry(st_transform(g, 3035)))); ox <- median(xy[, 1] %% 100); oy <- median(xy[, 2] %% 100)
  tibble(x = round((xy[, 1] - ox) / 100) * 100 + ox, y = round((xy[, 2] - oy) / 100) * 100 + oy)
}
councils <- st_read(here::here("data/malta/Population_Malta_Districts.geojson"), quiet = TRUE) %>%
  st_transform(3035) %>% group_by(NAME) %>% summarise(.groups = "drop") %>% st_intersection(st_union(areas$Malta))
panel <- function(cn, d, fill, scale, tag, bar) {
  b <- areas[[cn]]; bb <- st_bbox(b)
  mask <- st_sf(geometry = st_difference(st_as_sfc(st_bbox(st_buffer(b, 2000))), st_union(b)))
  ggplot() + geom_raster(data = mutate(d, f = fill), aes(x, y, fill = f), interpolate = FALSE) +
    geom_sf(data = mask, fill = "white", colour = NA) +
    (if (cn == "Malta") geom_sf(data = councils, fill = NA, colour = "grey75", linewidth = lw_pt(0.15))) +
    geom_sf(data = b, fill = NA, colour = "grey25", linewidth = lw_pt(0.3)) + scale +
    (if (bar) lancet_scale_bar("bl")) +
    coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], crs = 3035, datum = NA) +
    labs(tag = tag, x = NULL, y = NULL) + theme_lancet_map(base_size = 8) +
    theme(plot.tag = element_text(size = 8, face = "bold", hjust = 0), plot.tag.position = c(0, 1), legend.position = "bottom")
}
quint_colours <- c("Q1 (lowest)" = "#1a9641", "Q2" = "#a6d96a", "Q3" = "#ffffbf", "Q4" = "#fdae61",
                   "Q5 (highest)" = "#d73027", "No score" = "grey88")
qf <- function(p) { q <- top_q(p); factor(ifelse(is.na(q), "No score", names(quint_colours)[q]), levels = names(quint_colours)) }

# ---- Step 2. Water cells ----------------------------------------------------------------------
water_tab <- imap_dfr(D, function(x, cn) {
  q_old <- top_q(x$old$priority_citizen); w <- x$water
  tibble(city = cn, source = if (cn == "Malta") "Urban Atlas 2021" else "Urban Atlas 2018",
         water_cells = sum(w), constraint_cells_new = sum(x$new_mask), constraint_cells_old = sum(x$old_mask),
         water_scored_before = sum(w & !is.na(x$old$priority_citizen)),
         water_population = sum(x$pop[w], na.rm = TRUE),
         water_populated_cells = sum(w & x$pop > 0, na.rm = TRUE),
         Q1 = sum(w & q_old %in% 1), Q2 = sum(w & q_old %in% 2), Q3 = sum(w & q_old %in% 3),
         Q4 = sum(w & q_old %in% 4), Q5 = sum(w & q_old %in% 5), not_scored_before = sum(w & is.na(q_old)))
})
show(water_tab, "water_cells")
p_wq <- water_tab %>% select(city, Q1:not_scored_before) %>% pivot_longer(-city, names_to = "quintile", values_to = "cells") %>%
  mutate(quintile = factor(recode(quintile, not_scored_before = "Not scored"), levels = c("Q1", "Q2", "Q3", "Q4", "Q5", "Not scored"))) %>%
  ggplot(aes(quintile, cells, fill = city)) + geom_col(position = "dodge") +
  scale_fill_manual(values = city_cols, name = NULL) + labs(x = "Old priority quintile of the water cells", y = "Cells") +
  theme_lancet() + theme(legend.position = "bottom")
save_fig(p_wq, "water_cells_old_quintile", 70, 120)

rule_tab <- imap_dfr(D, function(x, cn) {
  maj <- x$water; sh <- !is.na(x$water_share) & x$water_share > 0.5
  tibble(city = cn, majority_class_water = sum(maj), share_over_50pct = sum(sh), both = sum(maj & sh),
         majority_only = sum(maj & !sh), share_only = sum(sh & !maj), cells_differing = sum(maj != sh))
})
show(rule_tab, "water_rule_majority_vs_share50")
p_rule <- rule_tab %>% select(city, both, majority_only, share_only) %>% pivot_longer(-city, names_to = "group", values_to = "cells") %>%
  mutate(group = factor(recode(group, both = "Both rules", majority_only = "Majority class only", share_only = "Water share > 50% only"),
                        levels = c("Both rules", "Majority class only", "Water share > 50% only"))) %>%
  ggplot(aes(city, cells, fill = group)) + geom_col() +
  scale_fill_manual(values = c("grey40", "#2c7fb8", "#fdae61"), name = NULL) + labs(x = NULL, y = "Water cells") +
  theme_lancet() + theme(legend.position = "bottom")
save_fig(p_rule, "water_rule_majority_vs_share50", 70, 120)

water_maps <- map(names(D), function(cn) {
  x <- D[[cn]]; d <- ras(x$new); q <- qf(x$old$priority_citizen)
  f <- factor(ifelse(x$water, as.character(q), "Not water"), levels = c(names(quint_colours), "Not water"))
  panel(cn, d, f, scale_fill_manual(values = c(quint_colours, `Not water` = "grey97"), name = "Water cells, old quintile", drop = FALSE),
        cn, TRUE)
})
save_fig(water_maps[[1]] + water_maps[[2]] + plot_layout(guides = "collect") & theme(legend.position = "bottom"), "water_cells_map", 110)

# ---- Step 5. Old vs new -----------------------------------------------------------------------
cells_tab <- imap_dfr(D, function(x, cn) {
  so <- !is.na(x$old$priority_citizen); sn <- !is.na(x$new$priority_citizen)
  tibble(city = cn, score = c("Old", "New"), eligible_cells = c(sum(!x$old_mask), sum(!x$new_mask)),
         scored_cells = c(sum(so), sum(sn)), population_scored = c(sum(x$pop[so], na.rm = TRUE), sum(x$pop[sn], na.rm = TRUE)))
})
show(cells_tab, "eligible_scored_population")
p_cells <- cells_tab %>% pivot_longer(c(eligible_cells, scored_cells, population_scored)) %>%
  mutate(score = factor(score, levels = c("Old", "New"))) %>%
  ggplot(aes(city, value, fill = score)) + geom_col(position = "dodge") + facet_wrap(~ name, scales = "free_y") +
  scale_fill_manual(values = score_cols, name = NULL) + labs(x = NULL, y = NULL) + theme_lancet() + theme(legend.position = "bottom")
save_fig(p_cells, "eligible_scored_population", 70)

oldnew <- imap_dfr(D, ~ pair(.x$old$priority_citizen, .x$new$priority_citizen) %>% mutate(city = .y, .before = 1))
show(oldnew, "old_vs_new_score")
eq <- imap_dfr(D, function(x, cn) bind_rows(pair(x$old$priority_citizen, x$old$priority_equal) %>% mutate(score = "Old"),
                                            pair(x$new$priority_citizen, x$new$priority_equal) %>% mutate(score = "New")) %>%
                 mutate(city = cn, .before = 1))
show(eq, "citizen_vs_equal")
p_cmp <- bind_rows(oldnew %>% mutate(comparison = "Old vs new citizen score"),
                   eq %>% mutate(comparison = paste0("Citizen vs equal weights, ", tolower(score), " score"))) %>%
  select(city, comparison, Spearman = spearman, `Top quintile overlap (%)` = top_quintile_overlap_pct) %>%
  pivot_longer(-c(city, comparison)) %>%
  ggplot(aes(value, comparison, colour = city)) + geom_point(size = 2) + facet_wrap(~ name, scales = "free_x") +
  scale_colour_manual(values = city_cols, name = NULL) + labs(x = NULL, y = NULL) + theme_lancet() + theme(legend.position = "bottom")
save_fig(p_cmp, "spearman_overlap", 70)

units_top <- imap_dfr(D, function(x, cn) map_dfr(c("Old", "New"), function(sc) {
  p <- if (sc == "Old") x$old$priority_citizen else x$new$priority_citizen; q <- top_q(p)
  tibble(unit = x$unit, q = q) %>% filter(!is.na(q), !is.na(unit)) %>% group_by(unit) %>%
    summarise(scored_cells = n(), top_quintile_cells = sum(q == 5), top_quintile_pct_of_unit = 100 * mean(q == 5), .groups = "drop") %>%
    filter(scored_cells >= 20) %>% arrange(desc(top_quintile_pct_of_unit), desc(top_quintile_cells)) %>% slice(1:5) %>%
    mutate(city = cn, score = sc, rank = 1:5, .before = 1)
}))
show(units_top, "top5_units")
p_units <- units_top %>% mutate(score = factor(score, levels = c("Old", "New")), label = paste(unit, sep = "")) %>%
  ggplot(aes(top_quintile_pct_of_unit, reorder(paste(city, unit), top_quintile_pct_of_unit), colour = score)) +
  geom_point(size = 2) + facet_wrap(~ city, scales = "free_y") + scale_colour_manual(values = score_cols, name = NULL) +
  labs(x = "Top quintile cells (% of the unit's scored cells)", y = NULL) + theme_lancet() + theme(legend.position = "bottom")
save_fig(p_units, "top5_units", 80)

# Normalisation bounds: old rule (as in the _pre_water notebooks) vs new rule (eligible cells only)
bnd <- function(x, ref, type) {
  x <- x[ref]
  switch(type, min_p98 = c(min(x, na.rm = TRUE), quantile(x, 0.98, na.rm = TRUE)),
         p98 = c(NA, quantile(x, 0.98, na.rm = TRUE)), p2_p98 = quantile(x, c(0.02, 0.98), na.rm = TRUE),
         log_p2_p98 = 10^quantile(ifelse(x > 0, log10(x), NA), c(0.02, 0.98), na.rm = TRUE),
         log1p10_p98 = c(NA, quantile(log10(x + 1), 0.98, na.rm = TRUE)))
}
spec_b <- list(
  Malta = tribble(~criterion, ~var, ~type, ~old_ref,
                  "Urban heat (LST)", "lst", "min_p98", "all",
                  "Blue space distance", "dist_bs", "p98", "all",
                  "Noise (Lden)", "Lden", "min_p98", "all",
                  "Air quality (NO2)", "no2_avg_21", "min_p98", "all",
                  "Recreation walking distance", "walk_dist_m", "p98", "all",
                  "Street canopy", "street_canopy_pct", "p98", "eligible",
                  "Green proximity (walking time)", "nearest_green_min", "p98", "eligible",
                  "Green per person (m2, log)", "green_m2_e2sfca_per_person_gauss", "log_p2_p98", "eligible_populated",
                  "Sensitivity: green proximity ATGreen", "nearest_green_min_atg", "p98", "eligible",
                  "Sensitivity: green per person step", "green_m2_e2sfca_per_person", "log_p2_p98", "eligible_populated",
                  "Sensitivity: green per person ATGreen", "green_m2_e2sfca_per_person_gauss_atg", "log_p2_p98", "eligible_populated",
                  "Sensitivity: green per person min max", "green_m2_e2sfca_per_person_gauss", "p98", "all",
                  "Sensitivity: Street Tree Layer 2018", "perc_tree", "p98", "all",
                  "Sensitivity: CAMS-REG log10(vkm + 1)", "traffic_vkm_cams", "log1p10_p98", "eligible"),
  Klagenfurt = tribble(~criterion, ~var, ~type, ~old_ref,
                       "Urban heat (LST)", "lst", "min_p98", "all",
                       "Blue space distance", "dist_bs", "p98", "all",
                       "NO2", "no2_final", "min_p98", "all",
                       "PM2.5", "pm25_final", "min_p98", "all",
                       "Green proximity (walking time)", "nearest_green_min", "p98", "all",
                       "Low income (weighted)", "income_weighted", "p2_p98", "all",
                       "Sensitivity: green proximity ATGreen", "nearest_green_min_atg", "p98", "all",
                       "Sensitivity: raw income", "income", "p2_p98", "all",
                       "Sensitivity: CAMS-REG log10(vkm + 1)", "traffic_vkm_cams", "log1p10_p98", "all",
                       "Sensitivity: OpenTransportMap log", "new_trafficvol", "p98", "all"))
bounds <- imap_dfr(spec_b, function(s, cn) {
  x <- D[[cn]]; d <- st_drop_geometry(x$new); populated <- x$pop > 0
  pmap_dfr(s, function(criterion, var, type, old_ref) {
    if (!var %in% names(d)) return(NULL)
    ref_old <- switch(old_ref, all = rep(TRUE, nrow(d)), eligible = !x$old_mask, eligible_populated = !x$old_mask & populated)
    ref_new <- if (old_ref == "eligible_populated") !x$new_mask & populated else !x$new_mask
    o <- bnd(d[[var]], ref_old, type); n <- bnd(d[[var]], ref_new, type)
    tibble(city = cn, criterion, variable = var, old_lower = o[1], new_lower = n[1], old_upper = o[2], new_upper = n[2],
           old_reference = old_ref, changed = !isTRUE(all.equal(unname(o), unname(n))))
  })
})
show(bounds, "normalisation_bounds")
p_b <- bounds %>% filter(changed) %>%
  select(city, criterion, old_lower, new_lower, old_upper, new_upper) %>%
  pivot_longer(-c(city, criterion), names_to = c("score", "bound"), names_sep = "_") %>% filter(!is.na(value)) %>%
  group_by(city, criterion, bound) %>% mutate(pct_change = 100 * (value / value[score == "old"] - 1)) %>% ungroup() %>%
  filter(score == "new") %>%
  ggplot(aes(pct_change, reorder(criterion, pct_change), colour = bound)) + geom_vline(xintercept = 0, colour = "grey60") +
  geom_point(size = 2) + facet_wrap(~ city, scales = "free_y") +
  scale_colour_manual(values = c(lower = "#2c7fb8", upper = "#d73027"), name = "Bound") +
  labs(x = "Change of the bound, new vs old (%)", y = NULL) + theme_lancet() + theme(legend.position = "bottom")
save_fig(p_b, "normalisation_bounds_changed", 90)
# Check: the new main normalisations reproduce from the new bounds
chk <- with(st_drop_geometry(D$Malta$new), {
  e <- !ua_not_eligible; lo <- min(lst[e], na.rm = TRUE); hi <- quantile(lst[e], 0.98, na.rm = TRUE)
  max(abs((pmin(pmax(lst, lo), hi) - lo) / (hi - lo) - norm_lst), na.rm = TRUE) })
stopifnot(chk < 1e-12)

# Step 3 main ratio (Burden_coincidence_random_weights.Rmd), old outputs from the _pre_water backup
s3 <- bind_rows(
  readr::read_csv(here::here("output/figures_mcda/_pre_water/burden_coincidence_2026_11_20/A3_tie_rule_shuffle_variants.csv"), show_col_types = FALSE) %>% mutate(score = "Old"),
  readr::read_csv(here::here("output/figures_mcda/burden_coincidence_2026_11_20/A3_tie_rule_shuffle_variants.csv"), show_col_types = FALSE) %>% mutate(score = "New")) %>%
  filter(grepl("main", variant)) %>%
  select(city, score, observed_pct, shuffled_mean_pct, shuffled_p5_pct, shuffled_p95_pct, ratio, ratio_p5, ratio_p95)
show(s3, "step3_main_ratio")
p_s3 <- s3 %>% mutate(score = factor(score, levels = c("Old", "New"))) %>%
  ggplot(aes(ratio, score, colour = city)) + geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_errorbarh(aes(xmin = ratio_p5, xmax = ratio_p95), height = 0.2) + geom_point(size = 2) + facet_wrap(~ city) +
  scale_colour_manual(values = city_cols, guide = "none") +
  labs(x = "Step 3 ratio observed / shuffled (interval from the 5th to 95th shuffle percentile)", y = NULL) + theme_lancet()
save_fig(p_s3, "step3_main_ratio", 60)

sens <- bind_rows(
  readRDS(here::here("data/malta/malta_sensitivity_pre_water.rds")) %>% mutate(city = "Malta", score = "Old"),
  readRDS(here::here("data/malta/malta_sensitivity.rds")) %>% mutate(city = "Malta", score = "New"),
  readRDS(here::here("data/klagenfurt/klag_sensitivity_pre_water.rds")) %>% mutate(city = "Klagenfurt", score = "Old"),
  readRDS(here::here("data/klagenfurt/klag_sensitivity.rds")) %>% mutate(city = "Klagenfurt", score = "New")) %>%
  select(city, score, test_name, spearman_r, class_agreement) %>%
  mutate(across(c(spearman_r, class_agreement), ~ suppressWarnings(as.numeric(gsub("%", "", .)))))
sens_w <- sens %>% pivot_wider(names_from = score, values_from = c(spearman_r, class_agreement))
show(sens_w, "sensitivity_old_new")
p_sens <- sens %>% mutate(score = factor(score, levels = c("Old", "New"))) %>%
  ggplot(aes(spearman_r, reorder(test_name, spearman_r), colour = score)) + geom_point(size = 1.5) +
  facet_wrap(~ city, scales = "free_y") + scale_colour_manual(values = score_cols, name = NULL) +
  labs(x = "Spearman, main score vs variant", y = NULL) + theme_lancet(base_size = 7) + theme(legend.position = "bottom")
save_fig(p_sens, "sensitivity_old_new", 150)

chg_tab <- list()
for (cn in names(D)) {
  d <- ras(D[[cn]]$new); po <- D[[cn]]$old$priority_citizen; pn <- D[[cn]]$new$priority_citizen
  qs <- scale_fill_manual(values = quint_colours, name = "Priority quintile", drop = FALSE)
  ch <- abs(top_q(po) - top_q(pn)) >= 1
  chg_tab[[cn]] <- tibble(city = cn, scored_in_both = sum(!is.na(ch)), changed_quintile = sum(ch, na.rm = TRUE),
                          changed_2plus = sum(abs(top_q(po) - top_q(pn)) >= 2, na.rm = TRUE),
                          newly_unscored = sum(!is.na(po) & is.na(pn)), newly_scored = sum(is.na(po) & !is.na(pn)))
  p <- panel(cn, d, qf(po), qs, "A  Old (before the water constraint)", TRUE) +
    panel(cn, d, qf(pn), qs, "B  New (water constraint)", FALSE) + plot_layout(guides = "collect") & theme(legend.position = "bottom")
  save_fig(p, paste0("priority_quintiles_old_new_", tolower(cn)), 110)
}
show(bind_rows(chg_tab), "cells_changing_quintile")
cat("\nOutputs in", OUT, "\n")
