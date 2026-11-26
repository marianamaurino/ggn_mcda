# Effects for mcda/instructions/2026_11_25_industrial_streetview_gpp_sensitivity.md:
#   Part 0: majority class = largest total area in the cell (Malta switched from the largest single piece), old
#           (*_pre_majority.rds) vs new score; constraint counts by class, scored cells, Spearman, top quintile
#           overlap, Step 3 main ratio.
#   Part C: Malta sensitivity, green per person = 0 in unpopulated cells (priority_gpp_na0) vs the main score.
#   Part E: headline numbers of Burden_coincidence_random_weights.Rmd (A to D) on the new scores.
# Outputs: output/figures_mcda/majority_rule_2026_11_25/ (tables as CSV, figures as PDF, SVG, PNG).
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 \
#      nice -n 10 Rscript mcda/majority_rule_effects.R

suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(sf); library(purrr); library(ggplot2); library(patchwork) })
source(here::here("R/theme_lancet.R"))
sf_use_s2(FALSE)
OUT <- here::here("output/figures_mcda/majority_rule_2026_11_25")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
BC  <- here::here("output/figures_mcda/burden_coincidence_2026_11_20")
BC_OLD <- here::here("output/figures_mcda/_pre_majority/burden_coincidence_2026_11_20")
lw_pt <- function(pt) pt / (ggplot2::.pt * 0.75)
save_fig <- function(p, name, h, w = 180) invisible(save_figure_lancet(p, name, OUT, height_mm = h, width_mm = w))
show <- function(x, nm) {
  cat("\n==", nm, "\n"); print(as.data.frame(mutate(x, across(where(is.double), ~ round(., 3)))), row.names = FALSE)
  readr::write_csv(x, file.path(OUT, paste0(nm, ".csv")))
}
city_cols <- c(Malta = "#2166ac", Klagenfurt = "#b2182b")
score_cols <- c(Old = "grey60", New = "black")
top_q <- function(p) { q <- rep(NA_integer_, length(p)); q[!is.na(p)] <- ntile(p[!is.na(p)], 5); q }
pair <- function(a, b) {
  qa <- top_q(a); qb <- top_q(b); k <- !is.na(a) & !is.na(b)
  tibble(cells_scored_in_both = sum(k), spearman = cor(a[k], b[k], method = "spearman"),
         top_quintile_overlap_pct = 100 * sum(qa == 5 & qb == 5 & k) / sum(qa == 5 & k),
         cells_changing_quintile_pct = 100 * mean(qa[k] != qb[k]),
         cells_changing_2plus = sum(abs(qa[k] - qb[k]) >= 2))
}

D <- list(
  Malta = list(old = readRDS(here::here("data/malta/malta_mcda_processed_realloc_pre_majority.rds")),
               new = readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds")), code = "ua_code_2021"),
  Klagenfurt = list(old = readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may_pre_majority.rds")),
                    new = readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")), code = "ua_code_2018"))
stopifnot(nrow(D$Malta$new) == 10657, identical(as.character(D$Malta$old$gid), as.character(D$Malta$new$gid)),
          nrow(D$Klagenfurt$new) == 12418, identical(D$Klagenfurt$old$ID, D$Klagenfurt$new$ID))

# ---- Part 0 ----------------------------------------------------------------------------------
cls <- c(`12400` = "Airport", `12300` = "Port", `50000` = "Water")
counts <- imap_dfr(D, function(x, cn) map_dfr(c("Old", "New"), function(sc) {
  d <- if (sc == "Old") x$old else x$new
  tibble(city = cn, score = sc, class = c(unname(cls), "Total constraint"),
         cells = c(sapply(names(cls), function(k) sum(d$ua_not_eligible & d[[x$code]] %in% k)), sum(d$ua_not_eligible)))
})) %>% filter(!(city == "Klagenfurt" & class %in% c("Airport", "Port")))
show(counts %>% pivot_wider(names_from = score, values_from = cells), "constraint_cells_by_class")
switched <- imap_dfr(D, function(x, cn) {
  o <- x$old$ua_not_eligible; n <- x$new$ua_not_eligible
  tibble(city = cn, cells_leaving_constraint = sum(o & !n), cells_entering_constraint = sum(!o & n),
         majority_class_changed = sum(x$old[[x$code]] != x$new[[x$code]], na.rm = TRUE))
})
show(switched, "constraint_cells_switched")
p_c <- counts %>% mutate(score = factor(score, levels = c("Old", "New"))) %>%
  ggplot(aes(class, cells, fill = score)) + geom_col(position = "dodge") + facet_wrap(~ city, scales = "free") +
  scale_fill_manual(values = score_cols, name = NULL) + labs(x = NULL, y = "Cells") + theme_lancet() + theme(legend.position = "bottom")
save_fig(p_c, "constraint_cells_by_class", 70)

scored <- imap_dfr(D, ~ tibble(city = .y, scored_old = sum(!is.na(.x$old$priority_citizen)),
                               scored_new = sum(!is.na(.x$new$priority_citizen))))
oldnew <- imap_dfr(D, ~ pair(.x$old$priority_citizen, .x$new$priority_citizen) %>% mutate(city = .y, .before = 1)) %>%
  left_join(scored, by = "city")
show(oldnew, "old_vs_new_score")
s3 <- bind_rows(readr::read_csv(file.path(BC_OLD, "A3_tie_rule_shuffle_variants.csv"), show_col_types = FALSE) %>% mutate(score = "Old"),
                readr::read_csv(file.path(BC, "A3_tie_rule_shuffle_variants.csv"), show_col_types = FALSE) %>% mutate(score = "New")) %>%
  filter(grepl("main", variant)) %>% select(city, score, observed_pct, shuffled_mean_pct, ratio, ratio_p5, ratio_p95)
show(s3, "step3_main_ratio")
p_on <- bind_rows(oldnew %>% transmute(city, measure = "Spearman, old vs new", value = spearman),
                  oldnew %>% transmute(city, measure = "Top quintile overlap (%)", value = top_quintile_overlap_pct)) %>%
  ggplot(aes(value, city, colour = city)) + geom_point(size = 2.2) + facet_wrap(~ measure, scales = "free_x") +
  scale_colour_manual(values = city_cols, guide = "none") + labs(x = NULL, y = NULL) + theme_lancet()
p_s3 <- s3 %>% mutate(score = factor(score, levels = c("Old", "New"))) %>%
  ggplot(aes(ratio, score, colour = city)) + geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_errorbar(aes(xmin = ratio_p5, xmax = ratio_p95), width = 0.2, orientation = "y") + geom_point(size = 2) +
  facet_wrap(~ city) + scale_colour_manual(values = city_cols, guide = "none") +
  labs(x = "Step 3 ratio (interval from the 5th to 95th shuffle percentile)", y = NULL) + theme_lancet()
save_fig(p_on / p_s3, "old_vs_new_and_step3", 110)

# ---- Part C (Malta) ------------------------------------------------------------------------
m <- D$Malta$new
stopifnot("priority_gpp_na0" %in% names(m))
pc <- pair(m$priority_citizen, m$priority_gpp_na0) %>%
  mutate(scored_main = sum(!is.na(m$priority_citizen)), scored_variant = sum(!is.na(m$priority_gpp_na0)),
         newly_scored = sum(is.na(m$priority_citizen) & !is.na(m$priority_gpp_na0)),
         newly_scored_top_quintile = sum(is.na(m$priority_citizen) & top_q(m$priority_gpp_na0) %in% 5), .before = 1)
show(pc, "partC_gpp_na0_vs_main")
units <- map_dfr(c(main = "priority_citizen", variant = "priority_gpp_na0"), function(v) {
  q <- top_q(m[[v]])
  tibble(council = m$NAME, q = q) %>% filter(!is.na(q)) %>% group_by(council) %>%
    summarise(scored_cells = n(), top_quintile_cells = sum(q == 5), top_quintile_pct = 100 * mean(q == 5), .groups = "drop") %>%
    filter(scored_cells >= 20) %>% arrange(desc(top_quintile_pct)) %>% slice(1:5) %>% mutate(rank = 1:5, .before = 1)
}, .id = "score")
show(units, "partC_top5_councils")
p_u <- units %>% ggplot(aes(top_quintile_pct, reorder(council, top_quintile_pct), colour = score)) + geom_point(size = 2) +
  scale_colour_manual(values = c(main = "grey60", variant = "black"), name = NULL) +
  labs(x = "Top quintile cells (% of the council's scored cells)", y = NULL) + theme_lancet() + theme(legend.position = "bottom")
save_fig(p_u, "partC_top5_councils", 70, 120)

areas_m <- st_sf(geometry = readRDS(here::here("data/malta/malta_union_boundary.rds")), crs = 3035)
councils <- st_read(here::here("data/malta/Population_Malta_Districts.geojson"), quiet = TRUE) %>%
  st_transform(3035) %>% group_by(NAME) %>% summarise(.groups = "drop") %>% st_intersection(st_union(areas_m))
qa <- top_q(m$priority_citizen); qb <- top_q(m$priority_gpp_na0)
chg <- case_when(is.na(qa) & !is.na(qb) ~ "Newly scored", abs(qa - qb) >= 2 ~ "Changed by 2 or more",
                 is.na(qa) ~ "Not scored", TRUE ~ "Changed by less than 2")
p_map <- ggplot() + geom_sf(data = m %>% mutate(f = factor(chg, levels = c("Changed by 2 or more", "Newly scored",
                                                                           "Changed by less than 2", "Not scored"))),
                            aes(fill = f), colour = NA) +
  geom_sf(data = councils, fill = NA, colour = "grey60", linewidth = lw_pt(0.15)) +
  geom_sf(data = areas_m, fill = NA, colour = "grey25", linewidth = lw_pt(0.3)) +
  scale_fill_manual(values = c("Changed by 2 or more" = "#7b3294", "Newly scored" = "#e66101",
                               "Changed by less than 2" = "grey88", "Not scored" = "white"), name = NULL, drop = FALSE) +
  lancet_scale_bar("bl") + theme_lancet_map(base_size = 8) + theme(legend.position = "bottom")
save_fig(p_map, "partC_quintile_change_map", 110)
show(tibble(class = c("Changed by 2 or more", "Newly scored", "Changed by less than 2", "Not scored")) %>%
       mutate(cells = sapply(class, function(k) sum(chg == k))), "partC_quintile_change_counts")

# ---- Part E: Burden_coincidence_random_weights.Rmd headline numbers ----------------------------
A <- readr::read_csv(file.path(BC, "A_burden_coincidence.csv"), show_col_types = FALSE) %>%
  select(city, mean_abs_spearman, pc1_variance_pct, step3_ratio = ratio_to_permuted)
B <- readr::read_csv(file.path(BC, "B_C1_random_weights_summary.csv"), show_col_types = FALSE)
Dd <- readr::read_csv(file.path(BC, "D_robust_contested.csv"), show_col_types = FALSE)
eq <- imap_dfr(D, ~ pair(.x$new$priority_citizen, .x$new$priority_equal) %>% mutate(city = .y, .before = 1)) %>%
  select(city, citizen_vs_equal_spearman = spearman, citizen_vs_equal_top_quintile_overlap_pct = top_quintile_overlap_pct)
show(A %>% left_join(eq, by = "city"), "partE_A_and_citizen_vs_equal")
show(B, "partE_B_C_random_weights")
show(Dd, "partE_D_robust_contested")
p_e <- B %>% ggplot(aes(spearman_median, set, colour = city)) +
  geom_errorbar(aes(xmin = spearman_p05, xmax = spearman_p95), width = 0.2, orientation = "y", position = position_dodge(0.4)) +
  geom_point(size = 2, position = position_dodge(0.4)) + scale_colour_manual(values = city_cols, name = NULL) +
  labs(x = "Spearman with equal weights, median (5th to 95th percentile), 1,000 draws", y = NULL) + theme_lancet() +
  theme(legend.position = "bottom")
p_d <- Dd %>% pivot_longer(c(cells_pct, residents_pct)) %>%
  mutate(name = recode(name, cells_pct = "Scored cells (%)", residents_pct = "Residents (%)")) %>%
  ggplot(aes(value, class, fill = city)) + geom_col(position = "dodge") + facet_wrap(~ name) +
  scale_fill_manual(values = city_cols, name = NULL) + labs(x = NULL, y = NULL) + theme_lancet() + theme(legend.position = "bottom")
save_fig(p_e / p_d, "partE_B_C_D", 120)
cat("\nOutputs in", OUT, "\n")
