# Effect on the priority score of each walking time / routing change of 2026-11-20, per city.
#
# Steps (each compared with the previous step and with the current score):
#   Malta:      current -> switch to our routing (walking time; old filter, no zero rule)
#               -> filter fix (walking time and green per person) -> zero rule (both)
#               -> walking time cap at p98 of eligible cells
#   Klagenfurt: current -> switch to our routing (ATGreen's classes incl. 32000) -> drop 32000
#               -> filter fix -> zero rule -> eligible cap (no change: every cell is eligible)
# Inputs: the saved scores (before the re-knit of 2026-11-20) and the own routing outputs, before
# (*_pre_nov20) and after the filter fix. Scores are recomputed with the notebooks' formulas.
# Outputs: output/figures_mcda/walk_time_switch_2026_11_20/
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 nice -n 10 Rscript mcda/walk_time_switch_effects.R

suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(sf); library(ggplot2) })
OUT <- here::here("output/figures_mcda/walk_time_switch_2026_11_20")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
normalize_minmax <- function(x, lower, upper) (pmax(pmin(x, upper), lower) - lower) / (upper - lower)
crit_mat <- function(df, w) as.matrix(as.data.frame(df)[, names(w), drop = FALSE])
wlc_avail <- function(df, w, eligible) {
  S <- crit_mat(df, w); A <- !is.na(S); S[!A] <- 0
  den <- as.numeric(A %*% w); out <- as.numeric(S %*% w) / den
  out[den / sum(w) < 0.80 - 1e-12 | !eligible] <- NA
  out
}
recover_weights <- function(df, vars, score) {
  cc <- df[complete.cases(as.data.frame(df)[, vars]) & !is.na(df[[score]]), ]
  fit <- lm(reformulate(vars, score, intercept = FALSE), data = cc)
  stopifnot(max(abs(residuals(fit))) < 1e-8); coef(fit)
}
cmp <- function(x, ref) {
  ok <- !is.na(x) & !is.na(ref); qx <- ntile(x[ok], 5); qr <- ntile(ref[ok], 5)
  c(spearman = cor(x[ok], ref[ok], method = "spearman"), cells_changing_quintile_pct = 100 * mean(qx != qr),
    top_quintile_retained_pct = 100 * mean(qx[qr == 5] == 5), cells = sum(ok))
}
chain_table <- function(steps, city) {
  bind_rows(lapply(seq_along(steps)[-1], function(k) {
    a <- cmp(steps[[k]], steps[[k - 1]]); b <- cmp(steps[[k]], steps[[1]])
    tibble(city = city, step = names(steps)[k],
           spearman_vs_previous = a["spearman"], cells_changing_quintile_vs_previous_pct = a["cells_changing_quintile_pct"],
           spearman_vs_current = b["spearman"], cells_changing_quintile_vs_current_pct = b["cells_changing_quintile_pct"],
           top_quintile_retained_vs_current_pct = b["top_quintile_retained_pct"], cells = b["cells"])
  })) %>% mutate(across(where(is.double), ~ round(., 3)))
}
qmap <- function(geom_sf_obj, id, ref, x, title) {
  ok <- !is.na(ref) & !is.na(x); d <- rep(NA_integer_, length(ref))
  d[ok] <- ntile(x[ok], 5) - ntile(ref[ok], 5)
  g <- geom_sf_obj %>% mutate(change = factor(ifelse(is.na(d), NA, pmax(pmin(d, 2), -2)), levels = -2:2,
                                              labels = c("-2 or more", "-1", "0", "+1", "+2 or more")))
  ggplot(g) + geom_sf(aes(fill = change), colour = NA) +
    scale_fill_manual(values = c("#2166ac", "#92c5de", "grey88", "#f4a582", "#b2182b"), na.value = "white",
                      name = "Quintile change\n(new minus current)", drop = FALSE) +
    labs(title = title, subtitle = sprintf("%.1f%% of scored cells change quintile", 100 * mean(d[ok] != 0))) +
    theme_void(base_size = 9)
}

# ==== Malta =======================================================================================
MD <- here::here("data/malta/accessibility_malta/own_routing")
m <- readRDS(here::here("data/malta/malta_mcda_processed_realloc_pre_nov20.rds"))  # 2026-11-19 score (baseline)
old <- readr::read_csv(file.path(MD, "e2sfca_own_routing_cells_pre_nov20.csv"), show_col_types = FALSE) %>%
  transmute(gid = as.character(gid), walk_old = own_nearest_sec / 60, gpp_old = own_gauss_nso)
new <- readr::read_csv(file.path(MD, "e2sfca_own_routing_cells.csv"), show_col_types = FALSE) %>%
  transmute(gid = as.character(gid), walk_fix = own_nearest_sec_nozero / 60, gpp_fix = own_gauss_nso_nozero,
            walk_zero = own_nearest_sec / 60, gpp_zero = own_gauss_nso)
md <- m %>% st_drop_geometry() %>% mutate(gid = as.character(gid)) %>%
  left_join(old, by = "gid") %>% left_join(new, by = "gid")
vars_m <- c("norm_lst", "norm_imd", "norm_dist_bs", "norm_Lden", "norm_traffic", "norm_no2", "norm_tree",
            "norm_green_time", "norm_dist_rec", "norm_green_exp")
w_m <- recover_weights(md, vars_m, "priority_citizen")
elig <- !md$ua_not_eligible; popd <- md$Total_Population > 0
norm_gpp_log <- function(x) {
  lx <- ifelse(!is.na(x) & x > 0, log10(x), NA_real_)
  lo <- quantile(lx[popd & elig], 0.02, na.rm = TRUE); hi <- quantile(lx[popd & elig], 0.98, na.rm = TRUE)
  out <- case_when(is.na(x) ~ NA_real_, x == 0 ~ 1, TRUE ~ 1 - (pmin(pmax(lx, lo), hi) - lo) / (hi - lo))
  out[!popd] <- NA_real_; out
}
norm_walk <- function(x, eligible_cap) normalize_minmax(x, 0, quantile(if (eligible_cap) x[elig] else x, 0.98, na.rm = TRUE))
score_m <- function(walk, gpp, cap) wlc_avail(md %>% mutate(norm_green_time = norm_walk(walk, cap),
                                                            norm_green_exp = norm_gpp_log(gpp)), w_m, elig)
# Checks: the saved inputs reproduce the saved score; the old own gpp is the score's input
stopifnot(max(abs(score_m(md$nearest_green_min, md$green_m2_e2sfca_per_person_gauss, FALSE) - md$priority_citizen),
              na.rm = TRUE) < 1e-9,
          max(abs(md$gpp_old - md$green_m2_e2sfca_per_person_gauss), na.rm = TRUE) < 1e-6)
steps_m <- list(
  "Current score"                                         = md$priority_citizen,
  "1 Switch walking time to our routing (old filter)"     = score_m(md$walk_old,  md$gpp_old,  FALSE),
  "2 Filter fix (walking time and green per person)"      = score_m(md$walk_fix,  md$gpp_fix,  FALSE),
  "3 Zero rule (walking time and green per person)"       = score_m(md$walk_zero, md$gpp_zero, FALSE),
  "4 Walking time cap at p98 of eligible cells"           = score_m(md$walk_zero, md$gpp_zero, TRUE))
tab_m <- chain_table(steps_m, "Malta")
ind_m <- tibble(city = "Malta",
  check = c("Walking time, filter fix: cells changed by > 0.5 min (%)", "Walking time, zero rule: cells changed (%)",
            "Green per person, filter fix: Spearman old vs new (populated)", "Green per person, zero rule: Spearman (populated)",
            "Walking time p98, all cells (min)", "Walking time p98, eligible cells (min)"),
  value = c(100 * mean(abs(md$walk_fix - md$walk_old) > 0.5, na.rm = TRUE),
            100 * mean(abs(md$walk_zero - md$walk_fix) > 1e-9, na.rm = TRUE),
            cor(md$gpp_old[popd], md$gpp_fix[popd], method = "spearman", use = "complete.obs"),
            cor(md$gpp_fix[popd], md$gpp_zero[popd], method = "spearman", use = "complete.obs"),
            quantile(md$walk_zero, 0.98, na.rm = TRUE), quantile(md$walk_zero[elig], 0.98, na.rm = TRUE)))
pm <- qmap(m %>% select(gid), md$gid, steps_m[[1]], steps_m[[length(steps_m)]], "Malta")

# ==== Klagenfurt ==================================================================================
KD <- here::here("data/klagenfurt/accessibility_klagenfurt/own_routing")
k <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may_pre_nov20.rds"))  # 2026-11-19 score (baseline)
stopifnot(nrow(k) == 12418, !anyDuplicated(k$ID))
kold <- readr::read_csv(file.path(KD, "e2sfca_own_routing_cells_pre_nov20.csv"), show_col_types = FALSE) %>%
  transmute(ID = as.character(gid), walk_atgcl = own_nearest_min_atgclasses, walk_old = own_nearest_min_500m2)
knew <- readr::read_csv(file.path(KD, "e2sfca_own_routing_cells.csv"), show_col_types = FALSE) %>%
  transmute(ID = as.character(gid), walk_fix = own_nearest_min_nozero, walk_zero = own_nearest_min)
kd <- k %>% st_drop_geometry() %>% mutate(ID = as.character(ID)) %>% left_join(kold, by = "ID") %>% left_join(knew, by = "ID")
vars_k <- c("norm_lst", "norm_dist_bs", "norm_no2", "norm_pm25", "norm_green_time", "norm_traffic_cat", "norm_income_weighted")
w_k <- recover_weights(kd, vars_k, "priority_citizen")
all_k <- rep(TRUE, nrow(kd))
score_k <- function(walk) wlc_avail(kd %>% mutate(norm_green_time = normalize_minmax(walk, 0, quantile(walk, 0.98, na.rm = TRUE))),
                                    w_k, all_k)
stopifnot(max(abs(score_k(kd$nearest_green_min) - kd$priority_citizen), na.rm = TRUE) < 1e-9)
steps_k <- list(
  "Current score"                                         = kd$priority_citizen,
  "1 Switch walking time to our routing (old filter, incl. 32000)" = score_k(kd$walk_atgcl),
  "1b Drop class 32000"                                   = score_k(kd$walk_old),
  "2 Filter fix"                                          = score_k(kd$walk_fix),
  "3 Zero rule"                                           = score_k(kd$walk_zero),
  "4 Walking time cap at p98 of eligible cells (all cells eligible: no change)" = score_k(kd$walk_zero))
tab_k <- chain_table(steps_k, "Klagenfurt")
ok_v <- is.finite(kd$walk_zero) & is.finite(kd$nearest_green_min)
ind_k <- tibble(city = "Klagenfurt",
  check = c("Walking time, filter fix: cells changed by > 0.5 min (%)", "Walking time, zero rule: cells changed (%)",
            "Spearman walking time, final own vs ATGreen (current input)"),
  value = c(100 * mean(abs(kd$walk_fix - kd$walk_old) > 0.5, na.rm = TRUE),
            100 * mean(abs(kd$walk_zero - kd$walk_fix) > 1e-9, na.rm = TRUE),
            cor(kd$walk_zero[ok_v], kd$nearest_green_min[ok_v], method = "spearman")))
pk <- qmap(k %>% mutate(ID = as.character(ID)) %>% select(ID), kd$ID, steps_k[[1]], steps_k[[length(steps_k)]], "Klagenfurt")

# ==== Output ======================================================================================
tab <- bind_rows(tab_m, tab_k); ind <- bind_rows(ind_m, ind_k) %>% mutate(value = round(value, 3))
readr::write_csv(tab, file.path(OUT, "score_effect_by_step.csv")); readr::write_csv(ind, file.path(OUT, "indicator_checks.csv"))
print(as.data.frame(tab)); print(as.data.frame(ind))
ggsave(file.path(OUT, "quintile_change_map_malta.png"), pm, width = 160, height = 140, units = "mm", dpi = 300, bg = "white")
ggsave(file.path(OUT, "quintile_change_map_klagenfurt.png"), pk, width = 160, height = 140, units = "mm", dpi = 300, bg = "white")
# Final scores, to check against the re-knitted notebooks
saveRDS(list(malta = tibble(gid = md$gid, final = steps_m[[length(steps_m)]]),
             klagenfurt = tibble(ID = kd$ID, final = steps_k[[length(steps_k)]])), file.path(OUT, "final_scores_expected.rds"))
cat("Saved to", OUT, "\n")
