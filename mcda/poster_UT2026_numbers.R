# Numbers and exports for the Urban Transitions 2026 poster (P3.56), MCDA paper, Malta and Klagenfurt.
#
# Reads only saved outputs and the survey files; does not re-run the MCDA scoring notebooks.
#   data/malta/malta_mcda_processed_realloc.rds      (mcda/Malta_MCDA_260702_realloc.Rmd)
#   data/klagenfurt/klagenfurt_mcda_priority_may.rds  (mcda/Klagenfurt_MCDA_260520.Rmd)
#   data/malta/maltasurvey_jun26.csv, data/klagenfurt/klagenfurtsurvey_responses260907.csv
# Writes tables, figures and a GeoPackage to output/figures_mcda/poster/.
#
# Run from the project root:
#   OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/poster_UT2026_numbers.R

suppressMessages({
  library(dplyr); library(tidyr); library(sf); library(ggplot2); library(patchwork)
})
source(here::here("R", "theme_lancet.R"))
lancet_font <- "hanken"  # poster font instead of Source Sans 3
# Poster font, all figures: Hanken Grotesk via showtext (text drawn as outlines in every format)
library(sysfonts); library(showtext)
font_add_google("Hanken Grotesk", "hanken")
showtext_auto(); showtext_opts(dpi = 300)
theme_set(theme_void(base_family = "hanken"))
update_geom_defaults("text", list(family = "hanken"))
update_geom_defaults("label", list(family = "hanken"))

# MCDA_VARIANT=pre_avail80 reads the backups saved before the available weight rule (2026-11-05)
# and writes to output/figures_mcda/poster_pre_avail80/, for old vs new comparisons
VARIANT <- Sys.getenv("MCDA_VARIANT", "")
SFX <- if (VARIANT == "") "" else paste0("_", VARIANT)
OUT <- here::here(paste0("output/figures_mcda/poster", SFX))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
cat("Run date:", format(Sys.time(), "%Y-%m-%d %H:%M"), "\n\n")
wcsv <- function(x, f) { readr::write_csv(x, file.path(OUT, f)); invisible(x) }

malta <- readRDS(here::here(paste0("data/malta/malta_mcda_processed_realloc", SFX, ".rds"))) %>% st_transform(3035)
klag  <- readRDS(here::here(paste0("data/klagenfurt/klagenfurt_mcda_priority_may", SFX, ".rds"))) %>% st_transform(3035)
cat("MCDA files:", if (VARIANT == "") "current" else VARIANT, "\n")
malta_border <- st_sf(geometry = readRDS(here::here("data/malta/malta_union_boundary.rds")), crs = 3035)
klag_border  <- readRDS(here::here("data/klagenfurt/klagenfurt_boundary.rds")) %>% st_transform(3035)
md <- st_drop_geometry(malta); kd <- st_drop_geometry(klag)
# Malta residents: new population grid (GHSL reallocated to residential cells, NSO Census 2021)
md <- md %>% left_join(st_read(here::here("data/malta/Population_Malta_reallocated_nso.gpkg"), quiet = TRUE) %>%
                         st_drop_geometry() %>% transmute(gid = as.character(gid), pop_nso = pop_reallocated_nso),
                       by = c("gid" = "gid"))
stopifnot(!anyNA(md$pop_nso))

# ---- 1-2. Survey samples and weights ------------------------------------------------------------
m_cols <- c("Lack.recreational.facilities", "overcrowding", "poor.accessibility", "lack.blue.spaces",
            "poor.airquality", "noise.pollution", "urban.heat", "lack.street.greenery",
            "grey.infrastracture", "traffic.dominance")
m_lab <- c("Lack of recreational facilities", "Overcrowding (green per person)", "Poor accessibility",
           "Lack of blue spaces", "Poor air quality", "Noise pollution", "Urban heat",
           "Lack of street greenery", "Grey infrastructure", "Traffic dominance")
m_norm <- c("norm_dist_rec", "norm_green_exp", "norm_green_time", "norm_dist_bs", "norm_no2",
            "norm_Lden", "norm_lst", "norm_tree", "norm_imd", "norm_traffic")
k_cols <- c("alloc_1_TooHotStreets", "alloc_2_GreenOutOfReach", "alloc_3_LowIncomeNeighborhoods",
            "alloc_4_HighTrafficAreas", "alloc_5_PoorAirQuality", "alloc_6_DisconnectedNatureWater")
k_lab <- c("Too-hot streets", "Green out of reach", "Low-income neighbourhoods", "High-traffic areas",
           "Poor air quality", "Disconnected nature/water")

ms <- read.csv(here::here("data/malta/maltasurvey_jun26.csv"))
ks_raw <- read.csv(here::here("data/klagenfurt/klagenfurtsurvey_responses260907.csv"))
# Klagenfurt exclusion, as in mcda/Klagenfurt_MCDA_260520.Rmd (resident-cleanup): former residents
ks <- ks_raw %>% filter(resident != "left-2-plus") %>%
  mutate(across(all_of(k_cols), ~ tidyr::replace_na(., 0)))
ks_all <- ks_raw %>% mutate(across(all_of(k_cols), ~ tidyr::replace_na(., 0)))
stopifnot(all(rowSums(ms[m_cols]) == 1000), all(rowSums(ks[k_cols]) == 1e6))

alloc_table <- function(df, cols, labs, total, city) {
  eq <- 100 / length(cols)
  bind_rows(lapply(seq_along(cols), function(i) {
    v <- 100 * df[[cols[i]]] / total
    tt <- t.test(v, mu = eq)
    tibble(city = city, n = length(v), criterion = labs[i], survey_column = cols[i],
           mean_pct = mean(v), ci_low = tt$conf.int[1], ci_high = tt$conf.int[2],
           equal_pct = eq, t = unname(tt$statistic), p_value = tt$p.value)
  }))
}
alloc <- bind_rows(alloc_table(ms, m_cols, m_lab, 1000, "Malta"),
                   alloc_table(ks, k_cols, k_lab, 1e6, "Klagenfurt"),
                   alloc_table(ks_all, k_cols, k_lab, 1e6, "Klagenfurt, all 184 (no exclusion)"))
wcsv(alloc %>% mutate(across(c(mean_pct, ci_low, ci_high, equal_pct, t), ~ round(., 2)),
                      p_value = signif(p_value, 3)), "q2_survey_allocations.csv")

cat("== 1. Klagenfurt sample\n")
d <- sort(as.Date(substr(ks_raw$timestamp, 1, 10)))
cat("Raw responses:", nrow(ks_raw), "| resident == left-2-plus (excluded):", sum(ks_raw$resident == "left-2-plus"),
    "| analysed:", nrow(ks), "\n")
cat("Responses received up to 2026-05-26:", sum(d <= as.Date("2026-05-26")),
    "| up to 2026-05-22:", sum(d <= as.Date("2026-05-22")), "| last response:", format(max(d)), "\n")

# Weights implied by the saved priority_citizen (exact linear combination of the norm_* columns)
implied <- function(df, vars) {
  cc <- df[complete.cases(df[c("priority_citizen", vars)]), ]
  fit <- lm(reformulate(vars, "priority_citizen", intercept = FALSE), data = cc)
  list(w = coef(fit), max_resid = max(abs(resid(fit))))
}
m_w <- setNames(alloc$mean_pct[alloc$city == "Malta"], m_norm); m_w <- m_w / sum(m_w)
k_weights <- function(a) {
  r <- setNames(a$mean_pct, k_cols)
  w <- c(norm_lst = r[[1]], norm_green_time = r[[2]], norm_traffic_cat = r[[4]],
         norm_income_weighted = r[[3]], norm_no2 = r[[5]] / 2, norm_pm25 = r[[5]] / 2, norm_dist_bs = r[[6]])
  w / sum(w)
}
k_w     <- k_weights(alloc %>% filter(city == "Klagenfurt"))
k_w_184 <- k_weights(alloc %>% filter(city == "Klagenfurt, all 184 (no exclusion)"))
m_imp <- implied(md, m_norm); k_imp <- implied(kd, names(k_w))
cat("Malta: max |implied - survey weight| =", signif(max(abs(m_imp$w[m_norm] - m_w)), 3),
    "(residual", signif(m_imp$max_resid, 2), ")\n")
cat("Klagenfurt: max |implied - weight n=182| =", signif(max(abs(k_imp$w[names(k_w)] - k_w)), 3),
    "| vs n=184:", signif(max(abs(k_imp$w[names(k_w)] - k_w_184)), 3), "\n\n")
# The saved Klagenfurt priority_citizen uses the weights of all 184 responses (the left-2-plus
# exclusion in the notebook postdates the saved rds), so robustness and contributions use those
k_w_182 <- k_w; k_w <- k_w_184
wcsv(bind_rows(tibble(city = "Malta", indicator = m_norm, weight = m_w),
               tibble(city = "Klagenfurt", indicator = names(k_w), weight = unname(k_w))) %>%
       mutate(weight_pct = round(100 * weight, 1), weight = round(weight, 4)), "q2_wlc_weights.csv")

# ---- 3. Robustness ------------------------------------------------------------------------------
top_overlap <- function(a, b) {             # % of top quintile cells of a also in top quintile of b
  ok <- !is.na(a) & !is.na(b)
  ta <- a[ok] >= quantile(a[ok], 0.8); tb <- b[ok] >= quantile(b[ok], 0.8)
  100 * sum(ta & tb) / sum(ta)
}
class_agree <- function(a, b) {             # % of cells in the same quintile (own breaks)
  ok <- !is.na(a) & !is.na(b)
  100 * mean(dplyr::ntile(a[ok], 5) == dplyr::ntile(b[ok], 5))
}
robust <- function(df, w, city) {
  # Available weight rule (2026-11-05): weighted mean over the criteria present, on the scored cells
  X <- as.matrix(df[names(w)]); base <- df$priority_citizen
  wavg <- function(wv) { A <- !is.na(X); X0 <- X; X0[!A] <- 0
    out <- as.vector(X0 %*% wv) / as.vector(A %*% wv); out[is.na(base)] <- NA; out }
  eq <- tibble(city = city, test = "Citizen vs equal weights",
               spearman = cor(base, df$priority_equal, method = "spearman", use = "complete.obs"),
               top_quintile_overlap = top_overlap(base, df$priority_equal),
               five_class_agreement = class_agree(base, df$priority_equal))
  pert <- bind_rows(lapply(names(w), function(v) bind_rows(lapply(c(-0.2, 0.2), function(dl) {
    wp <- w; wp[v] <- w[v] * (1 + dl); o <- setdiff(names(w), v)
    wp[o] <- w[o] / sum(w[o]) * (1 - wp[v])
    s <- wavg(wp)
    tibble(city = city, test = sprintf("%s %+d%%", v, round(100 * dl)),
           spearman = cor(base, s, method = "spearman", use = "complete.obs"),
           top_quintile_overlap = top_overlap(base, s), five_class_agreement = class_agree(base, s))
  }))))
  list(eq = eq, pert = pert)
}
rm_ <- robust(md, m_w, "Malta"); rk_ <- robust(kd, k_w, "Klagenfurt")
cat("Pearson r citizen vs equal: Malta", round(cor(md$priority_citizen, md$priority_equal, use = "complete.obs"), 3),
    "| Klagenfurt", round(cor(kd$priority_citizen, kd$priority_equal, use = "complete.obs"), 3), "\n")
s182 <- as.vector(as.matrix(kd[names(k_w_182)]) %*% k_w_182)
cat("Klagenfurt n=182 weights vs saved (n=184) priority: Spearman",
    round(cor(kd$priority_citizen, s182, method = "spearman", use = "complete.obs"), 4),
    "| top quintile overlap", round(top_overlap(kd$priority_citizen, s182), 1), "%\n")
pert_all <- bind_rows(rm_$pert, rk_$pert)
rob_summary <- bind_rows(
  rm_$eq, rk_$eq,
  pert_all %>% group_by(city) %>%
    summarise(test = "±20% perturbation, range (min)", spearman = min(spearman),
              top_quintile_overlap = min(top_quintile_overlap),
              five_class_agreement = min(five_class_agreement), .groups = "drop"),
  pert_all %>% group_by(city) %>%
    summarise(test = "±20% perturbation, range (max)", spearman = max(spearman),
              top_quintile_overlap = max(top_quintile_overlap),
              five_class_agreement = max(five_class_agreement), .groups = "drop")) %>%
  mutate(spearman = round(spearman, 3), across(c(top_quintile_overlap, five_class_agreement), ~ round(., 1)))
wcsv(rob_summary, "q3_robustness_summary.csv")
wcsv(pert_all %>% mutate(spearman = round(spearman, 4),
                         across(c(top_quintile_overlap, five_class_agreement), ~ round(., 1))),
     "q3_perturbation_detail.csv")
cat("== 3. Robustness\n"); print(as.data.frame(rob_summary)); cat("\n")

# ---- 4-5. Study areas ---------------------------------------------------------------------------
area_km2 <- function(x) as.numeric(sum(st_area(x))) / 1e6
land <- function(x, b) area_km2(suppressWarnings(st_intersection(st_geometry(x), st_union(st_geometry(b)))))
klag_adult_share <- 0.8185  # 20+ share, data/popdata/allcause_counts_prop21.csv (as in HIA_klagenfurt.Rmd)
study <- tibble(
  city = c("Malta", "Klagenfurt"),
  grid_cells = c(nrow(malta), nrow(klag)),
  cells_with_priority = c(sum(!is.na(md$priority_citizen)), sum(!is.na(kd$priority_citizen))),
  cells_no_score = c(sum(is.na(md$priority_citizen)), sum(is.na(kd$priority_citizen))),
  grid_area_km2 = c(area_km2(malta), area_km2(klag)),
  land_area_km2 = c(land(malta, malta_border), land(klag, klag_border)),
  local_councils = c(n_distinct(md$NAME), NA),
  population_mcda_grid = c(sum(md$Total_Population, na.rm = TRUE), sum(kd$popdense_2020, na.rm = TRUE)),
  adults_mcda_grid = c(sum(md$Adult_Population, na.rm = TRUE),
                       klag_adult_share * sum(kd$popdense_2020, na.rm = TRUE)),
  populated_cells = c(sum(md$Total_Population > 0, na.rm = TRUE), sum(kd$popdense_2020 > 0, na.rm = TRUE)),
  population_new_grid = c(sum(md$pop_nso), NA),
  populated_cells_new_grid = c(sum(md$pop_nso > 0), NA)) %>%
  mutate(across(c(grid_area_km2, land_area_km2), ~ round(., 1)),
         across(c(population_mcda_grid, adults_mcda_grid), ~ round(.)))
wcsv(study, "q4_q5_study_area.csv")
cat("== 4-5. Study area\n"); print(as.data.frame(study))
cat("Malta councils in grid:", paste(sort(unique(md$NAME)), collapse = "; "), "\n\n")

# ---- 6. Traffic ---------------------------------------------------------------------------------
traffic <- bind_rows(
  md %>% transmute(city = "Malta", pop = pop_nso, vol = new_trafficvol,
                   own_high = norm_traffic == 1),
  kd %>% transmute(city = "Klagenfurt", pop = popdense_2020, vol = new_trafficvol,
                   own_high = new_trafficvol > 564)) %>%
  filter(pop > 0) %>%
  group_by(city) %>%
  summarise(populated_cells = n(),
            own_high_class_rule = first(ifelse(city == "Malta", "> 200 (norm_traffic = 1)", "> 564 (above p98)")),
            pct_residents_own_high = 100 * sum(pop[own_high %in% TRUE]) / sum(pop),
            pct_cells_own_high = 100 * mean(own_high %in% TRUE),
            pct_residents_over_564 = 100 * sum(pop[vol > 564 & !is.na(vol)]) / sum(pop),
            pct_cells_with_traffic = 100 * mean(vol > 0 & !is.na(vol)),
            median_vol_all_populated = median(replace_na(vol, 0)),
            median_vol_cells_with_traffic = median(vol[vol > 0 & !is.na(vol)]),
            .groups = "drop") %>%
  mutate(across(where(is.double), ~ round(., 1)))
wcsv(traffic, "q6_traffic.csv")
cat("== 6. Traffic (populated cells)\n"); print(as.data.frame(traffic)); cat("\n")

# ---- 7-8. Green and environmental medians, all cells and populated cells -------------------------
env <- function(df, city, pop, no2, pm25 = NULL, tree = NULL, gpp = NULL) {
  df <- df %>% mutate(.pop = .data[[pop]])
  one <- function(x, basis) {
    x %>% summarise(
      city = city, basis = basis, cells = n(),
      pct_cells_green_5min = 100 * mean(nearest_green_min <= 5, na.rm = TRUE),
      pct_cells_green_10min = 100 * mean(nearest_green_min <= 10, na.rm = TRUE),
      pct_pop_green_5min = 100 * sum(.pop[nearest_green_min <= 5], na.rm = TRUE) / sum(.pop[!is.na(nearest_green_min)], na.rm = TRUE),
      pct_pop_green_10min = 100 * sum(.pop[nearest_green_min <= 10], na.rm = TRUE) / sum(.pop[!is.na(nearest_green_min)], na.rm = TRUE),
      median_walk_min = median(nearest_green_min, na.rm = TRUE),
      median_tree_pct = if (is.null(tree)) NA_real_ else median(.data[[tree]], na.rm = TRUE),
      mean_tree_pct = if (is.null(tree)) NA_real_ else mean(.data[[tree]], na.rm = TRUE),
      pct_cells_tree_0 = if (is.null(tree)) NA_real_ else 100 * mean(.data[[tree]] == 0, na.rm = TRUE),
      median_green_m2_per_person = if (is.null(gpp)) NA_real_ else median(.data[[gpp]], na.rm = TRUE),
      median_lst_C = median(lst, na.rm = TRUE),
      median_no2 = median(.data[[no2]], na.rm = TRUE),
      median_pm25 = if (is.null(pm25)) NA_real_ else median(.data[[pm25]], na.rm = TRUE))
  }
  bind_rows(one(df, "all cells"), one(filter(df, .pop > 0), "populated cells"))
}
envt <- bind_rows(
  env(md, "Malta", "pop_nso", "no2_avg_21", tree = "perc_tree", gpp = "green_m2_e2sfca_per_person_gauss"),
  env(kd, "Klagenfurt", "popdense_2020", "no2_final", pm25 = "pm25_final")) %>%
  mutate(across(where(is.double), ~ round(., 1)))
wcsv(envt, "q7_q8_green_environment.csv")
cat("== 7-8. Green and environment\n"); print(as.data.frame(envt)); cat("\n")

# ---- 9. Results text -------------------------------------------------------------------------------
m_top <- md %>% filter(!is.na(priority_citizen)) %>%
  mutate(top = priority_citizen >= quantile(priority_citizen, 0.8))
hot <- m_top %>% group_by(local_council = NAME) %>%
  summarise(cells = n(), top_cells = sum(top), pct_cells_top = 100 * mean(top),
            top_residents = sum(pop_nso[top], na.rm = TRUE), .groups = "drop") %>%
  mutate(share_of_all_top_cells = 100 * top_cells / sum(top_cells)) %>%
  arrange(desc(pct_cells_top)) %>% mutate(across(where(is.double), ~ round(., 1)))
wcsv(hot, "q9a_malta_top_quintile_by_council.csv")
cat("== 9a. Malta councils by % of cells in the top quintile (councils with >= 20 cells)\n")
print(as.data.frame(head(filter(hot, cells >= 20), 10)))

contrib <- function(df, w, city) {
  t <- df %>% filter(!is.na(priority_citizen), priority_citizen >= quantile(priority_citizen, 0.8, na.rm = TRUE))
  tibble(city = city, indicator = names(w),
         mean_norm = sapply(names(w), function(v) mean(t[[v]], na.rm = TRUE)), weight = unname(w)) %>%
    mutate(contribution = mean_norm * weight, share_pct = 100 * contribution / sum(contribution)) %>%
    arrange(desc(contribution))
}
ctb <- bind_rows(contrib(md, m_w, "Malta"), contrib(kd, k_w, "Klagenfurt")) %>%
  mutate(across(where(is.double), ~ round(., 3)))
wcsv(ctb, "q9b_top_quintile_contributions.csv")
kc <- ctb %>% filter(city == "Klagenfurt")
cat("\n== 9b. Klagenfurt top quintile contributions\n"); print(as.data.frame(kc))
cat("Heat > next two combined:", kc$contribution[1] > sum(kc$contribution[2:3]),
    sprintf("(%.3f vs %.3f)\n\n", kc$contribution[1], sum(kc$contribution[2:3])))

# ---- 10. Exports ----------------------------------------------------------------------------------
survey_panel <- function(a, equal_pct, x_pad) {
  a <- a %>% mutate(criterion = factor(criterion, levels = criterion[order(mean_pct)]),
                    direction = ifelse(mean_pct > equal_pct, "above", "below"),
                    sig = case_when(p_value < 0.001 ~ "***", p_value < 0.01 ~ "**",
                                    p_value < 0.05 ~ "*", TRUE ~ "ns"))
  ggplot(a, aes(x = mean_pct, y = criterion, colour = direction)) +
    geom_vline(xintercept = equal_pct, linetype = "dashed", colour = "grey45", linewidth = 0.3) +
    geom_segment(aes(x = ci_low, xend = ci_high, yend = criterion), linewidth = 0.5) +
    geom_point(size = 1.6) +
    geom_text(aes(x = ci_high + x_pad, label = sig), size = pt_size(7), hjust = 0, colour = "black",
              family = lancet_font) +
    scale_colour_manual(values = c(above = "#1a7a2e", below = "#b84c4c"), guide = "none") +
    scale_x_continuous(name = "Mean budget allocation (%)", limits = c(NA, max(a$ci_high) + 3 * x_pad),
                       expand = expansion(mult = c(0.02, 0.01))) +
    labs(y = NULL, subtitle = sprintf("n = %d; dashed line = equal weight (%s%%)", a$n[1],
                                      format(round(equal_pct, 1)))) +
    theme_lancet() + theme(plot.margin = margin(4, 4, 3, 3))
}
save3 <- function(p, name, w, h) {
  ggsave(file.path(OUT, paste0(name, ".png")), p, width = w, height = h, units = "mm",
         device = ragg::agg_png, res = 300, bg = "white")
  ggsave(file.path(OUT, paste0(name, ".svg")), p, width = w, height = h, units = "mm",
         device = svglite::svglite, bg = "white", fix_text_size = FALSE)
  ggsave(file.path(OUT, paste0(name, ".pdf")), p, width = w, height = h, units = "mm",
         device = grDevices::cairo_pdf, bg = "white")
}
save3(survey_panel(filter(alloc, city == "Malta"), 10, 0.35), "panelA_survey_Malta", 100, 85)
# n = 184, the sample behind the saved Klagenfurt priority map (see section 1)
save3(survey_panel(filter(alloc, city == "Klagenfurt, all 184 (no exclusion)"), 100 / 6, 0.3), "panelA_survey_Klagenfurt", 100, 65)

# Exposure maps, priority map style: quintile classes of the raw indicator, clipped and dissolved
exposure_map <- function(sfx, var, border, title, pal, bar = "bl", digits = 0, breaks = NULL, labels = NULL) {
  v <- sfx[[var]]; br <- if (is.null(breaks)) quantile(v, seq(0, 1, 0.2), na.rm = TRUE) else breaks
  stopifnot(!anyDuplicated(br))
  lab <- sprintf("%s–%s", formatC(head(br, -1), format = "f", digits = digits),
                 formatC(br[-1], format = "f", digits = digits))
  if (!is.null(labels)) lab <- labels
  lv <- if (anyNA(v)) c(lab, "No data") else lab
  x <- sfx %>% mutate(cls = cut(v, br, include.lowest = TRUE, labels = lab),
                      cls = factor(ifelse(is.na(cls), "No data", as.character(cls)), levels = lv)) %>%
    select(cls) %>% st_buffer(0.5) %>% st_set_agr("constant") %>%
    st_intersection(st_union(st_geometry(border))) %>% st_collection_extract("POLYGON") %>%
    group_by(cls) %>% summarise(.groups = "drop")
  bb <- st_bbox(border)
  ggplot() +
    geom_sf(data = x, aes(fill = cls), colour = NA) +
    geom_sf(data = border, fill = NA, colour = "grey25", linewidth = 0.2) +
    scale_fill_manual(values = c(setNames(pal, lab), "No data" = "#b8c2cc"), name = title, drop = FALSE) +
    lancet_scale_bar(bar) + lancet_north_arrow("tr") +
    coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], datum = NA) +
    guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
    theme_lancet_map() +
    theme(legend.position = "bottom", legend.title.position = "top", legend.key.size = unit(3, "mm"),
          plot.margin = margin(3, 3, 3, 3))
}
save3(exposure_map(malta, "imd", malta_border, "Imperviousness (%), quintiles",
                   c("#f2f0f7", "#cbc9e2", "#9e9ac8", "#756bb1", "#54278f")),
      "exposure_map_Malta_imperviousness", 80, 95)
# Tree cover is 0 in most cells, so fixed classes instead of quintiles
save3(exposure_map(malta, "perc_tree", malta_border, "Street tree cover (%)",
                   c("#edf8e9", "#bae4b3", "#74c476", "#31a354", "#006d2c"),
                   breaks = c(0, 0.001, 2, 5, 10, 100), labels = c("0", ">0–2", "2–5", "5–10", ">10")),
      "exposure_map_Malta_tree_cover", 80, 95)
save3(exposure_map(klag, "lst", klag_border, "Land surface temperature (°C), quintiles",
                   c("#fee5d9", "#fcae91", "#fb6a4a", "#de2d26", "#a50f15"), bar = "br", digits = 1),
      "exposure_map_Klagenfurt_LST", 80, 95)

# Accessibility and proximity data on the MCDA grid (EPSG:3035), for restyling the maps
st_write(malta %>% select(gid, local_council = NAME, Total_Population, nearest_green_min,
                          nearest_green_min_median, green_access_class, walk_dist_m, green_ha_osm, green_ha_ua,
                          green_m2_e2sfca_per_person_gauss, perc_tree, priority_citizen),
         file.path(OUT, "accessibility_grid_malta.gpkg"), delete_dsn = TRUE, quiet = TRUE)
st_write(klag %>% select(gid, popdense_2020, nearest_green_min, recreation_m2, street_green_m2, perc_green,
                         priority_citizen),
         file.path(OUT, "accessibility_grid_klagenfurt.gpkg"), delete_dsn = TRUE, quiet = TRUE)
cat("Exports written to", OUT, "\n")
print(list.files(OUT))
