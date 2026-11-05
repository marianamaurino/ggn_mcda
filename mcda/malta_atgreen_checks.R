# Malta: ATGreen (Schifanella) accessibility / exposure outputs vs the study grid and population.
# Questions of 2026-11-05 (green per person E2SFCA, new population grid, ATGreen proximity outputs).
# Reads only saved files; does not re-run the MCDA. Writes CSVs, two figures and a report to
# output/figures_mcda/atgreen_checks/.
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/malta_atgreen_checks.R

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(sf); library(arrow); library(ggplot2)
})
OUT <- here::here("output/figures_mcda/atgreen_checks")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
wcsv <- function(x, f) readr::write_csv(x, file.path(OUT, f))
rd_pq <- function(p) read_parquet(here::here(p)) %>% as.data.frame()

# ---- Inputs ---------------------------------------------------------------------------------------
ATG <- "accessibility_schifanella"
ex  <- rd_pq(file.path(ATG, "exposure/results/final_metrics.parquet"))   # E2SFCA run, 2026-06-01
nr  <- rd_pq(file.path(ATG, "nearest/results/final_metrics.parquet"))    # nearest green run, 2026-06-01
ex_mcda <- rd_pq("mcda/exposure/final_metrics.parquet")                  # what the MCDA reads
nr_mcda <- rd_pq("mcda/accessibility/final_metrics.parquet")

pop <- st_read(here::here("data/malta/Population_Malta_reallocated_nso.gpkg"), quiet = TRUE)
m   <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds"))
border <- readRDS(here::here("data/malta/malta_union_boundary.rds"))
acc <- st_read(here::here("output/figures_mcda/poster/accessibility_grid_malta.gpkg"), quiet = TRUE)

g <- m %>%
  select(gid, NAME, Total_Population, nearest_green_min, green_m2_e2sfca_per_person_gauss,
         starts_with("norm_"), priority_citizen) %>%
  mutate(gid = as.character(gid)) %>%
  left_join(pop %>% st_drop_geometry() %>% transmute(gid = as.character(gid), pop_nso = pop_reallocated_nso),
            by = "gid")
stopifnot(nrow(g) == 10657, abs(sum(g$pop_nso) - 346005) < 1)

atg <- ex %>% select(-geometry) %>%
  transmute(gid = as.character(unit_id), unit_area_ha, assignment_status, connector_m,
            pop_atg = population, gpp_gauss = green_m2_e2sfca_per_person_gauss,
            gpp_step = green_m2_e2sfca_per_person) %>%
  left_join(nr %>% transmute(gid = as.character(unit_id), nearest_green_sec), by = "gid")

# ---- 0. Are the new ATGreen files the ones the MCDA already uses? ---------------------------------
same <- function(a, b) isTRUE(all.equal(a %>% select(-geometry) %>% arrange(unit_id),
                                        b %>% select(-geometry) %>% arrange(unit_id),
                                        check.attributes = FALSE))
q0 <- tibble(file = c("exposure/final_metrics.parquet", "nearest (accessibility)/final_metrics.parquet"),
             identical_to_mcda_input = c(same(ex, ex_mcda), same(nr, nr_mcda)))
wcsv(q0, "q0_new_vs_mcda_inputs.csv"); print(q0)

# ---- 1. Population: ATGreen vs new grid (GHSL reallocated, NSO 2021) ------------------------------
j1 <- g %>% st_drop_geometry() %>% inner_join(atg, by = "gid")
pop_tab <- function(thr) {
  a <- j1$pop_atg >= thr; b <- j1$pop_nso >= thr
  tibble(threshold = ifelse(thr == 1e-9, ">0", paste0(">=", thr)),
         populated_both = sum(a & b), populated_atg_only = sum(a & !b),
         populated_nso_only = sum(!a & b), unpopulated_both = sum(!a & !b),
         switching = sum(a != b), switching_pct = round(100 * mean(a != b), 1),
         nso_pop_in_atg_unpopulated = round(sum(j1$pop_nso[!a])),
         atg_pop_in_nso_unpopulated = round(sum(j1$pop_atg[!b])))
}
q1_tot <- tibble(
  layer = c("ATGreen population (GHSL R2023A 2020, 3ss)", "New grid pop_reallocated_nso", "MCDA Total_Population (Khomenko, DHIR)"),
  total_all_cells = c(sum(atg$pop_atg), sum(g$pop_nso), sum(g$Total_Population)),
  n_cells = c(nrow(atg), nrow(g), nrow(g)),
  total_on_10617_common_cells = c(sum(j1$pop_atg), sum(j1$pop_nso), sum(j1$Total_Population)),
  spearman_vs_nso_all_common = c(cor(j1$pop_atg, j1$pop_nso, method = "spearman"), 1,
                                 cor(j1$Total_Population, j1$pop_nso, method = "spearman")),
  spearman_vs_nso_cells_populated_in_either = c(
    with(filter(j1, pop_atg > 0 | pop_nso > 0), cor(pop_atg, pop_nso, method = "spearman")), 1,
    with(filter(j1, Total_Population > 0 | pop_nso > 0), cor(Total_Population, pop_nso, method = "spearman"))),
  pearson_vs_nso_all_common = c(cor(j1$pop_atg, j1$pop_nso), 1, cor(j1$Total_Population, j1$pop_nso))) %>%
  mutate(across(where(is.double), ~ round(., 3)))
q1_sw <- bind_rows(pop_tab(1e-9), pop_tab(1))
wcsv(q1_tot, "q1_population_totals.csv"); wcsv(q1_sw, "q1_population_switching.csv")
print(q1_tot); print(q1_sw)

# Sanity check: summary and scatter of the two population layers
print(summary(j1[, c("pop_atg", "pop_nso")]))
p1 <- ggplot(j1, aes(pop_nso, pop_atg)) +
  geom_point(size = 0.3, alpha = 0.3) + geom_abline(linetype = "dashed", colour = "red") +
  labs(x = "New grid, residents per cell (GHSL reallocated, NSO 2021)",
       y = "ATGreen population per cell (GHSL 3ss)",
       title = sprintf("Malta, %d common cells; Spearman r = %.2f", nrow(j1),
                       cor(j1$pop_atg, j1$pop_nso, method = "spearman"))) +
  theme_minimal(base_size = 9)
ggsave(file.path(OUT, "q1_population_scatter.png"), p1, width = 140, height = 120, units = "mm", dpi = 200)

# ---- 2. Cell sets: the 40 cells missing from ATGreen ----------------------------------------------
miss <- g %>% filter(!gid %in% atg$gid)
extra <- setdiff(atg$gid, g$gid)
bnd <- st_cast(st_union(st_sf(geometry = border)), "MULTILINESTRING")
bpoly <- st_union(st_geometry(st_sf(geometry = border)))
inside_ha <- vapply(seq_len(nrow(miss)), function(i) {
  x <- st_intersection(st_geometry(miss)[i], bpoly)
  if (length(x) == 0) 0 else sum(as.numeric(st_area(x))) / 1e4
}, numeric(1))
miss <- miss %>%
  mutate(cell_area_inside_boundary_ha = inside_ha,
         dist_centroid_to_boundary_m = as.numeric(st_distance(st_centroid(st_geometry(miss)), bnd)),
         in_mcda_score = !is.na(priority_citizen))
q2 <- miss %>% st_drop_geometry() %>%
  select(gid, local_council = NAME, cell_area_inside_boundary_ha, dist_centroid_to_boundary_m,
         Total_Population, pop_nso, nearest_green_min, green_m2_e2sfca_per_person_gauss,
         norm_green_time, norm_green_exp, priority_citizen, in_mcda_score) %>%
  mutate(across(where(is.double), ~ round(., 2)))
wcsv(q2, "q2_cells_missing_from_atgreen.csv")
cat("\nATGreen ids not in my grid:", length(extra), "| my cells missing from ATGreen:", nrow(miss), "\n")
cat("Of those, with a priority score:", sum(q2$in_mcda_score), "| NSO residents in them:", round(sum(q2$pop_nso)), "\n")
print(summary(q2$cell_area_inside_boundary_ha))
# ATGreen cells clipped by the boundary (unit_area_ha < 1)
cat("ATGreen cells with unit_area_ha < 0.999:", sum(atg$unit_area_ha < 0.999), "\n")

# Geometry: are ATGreen cells the same squares as mine?
atg_geom <- st_as_sfc(structure(as.list(ex$geometry), class = "WKB"), crs = 3035)
geo <- tibble(gid = as.character(ex$unit_id), c_atg = st_centroid(atg_geom), a_atg = as.numeric(st_area(atg_geom))) %>%
  inner_join(tibble(gid = g$gid, c_me = st_centroid(st_geometry(g)), a_me = as.numeric(st_area(st_geometry(g)))), by = "gid")
geo_chk <- tibble(
  common_cells = nrow(geo),
  max_centroid_shift_m = max(as.numeric(st_distance(st_sfc(geo$c_atg, crs = 3035), st_sfc(geo$c_me, crs = 3035), by_element = TRUE))),
  cells_area_differs_gt_1m2 = sum(abs(geo$a_atg - geo$a_me) > 1),
  median_area_atg_m2 = median(geo$a_atg))
wcsv(geo_chk, "q2_geometry_check.csv"); print(geo_chk)

# ---- 4. Priority score without green per person ---------------------------------------------------
norm_vars <- c("norm_lst", "norm_imd", "norm_dist_bs", "norm_Lden", "norm_traffic", "norm_no2",
               "norm_tree", "norm_green_time", "norm_dist_rec", "norm_green_exp")
d4 <- g %>% st_drop_geometry() %>% filter(!is.na(priority_citizen))
# Recover the citizen weights from the saved score (exact linear combination)
fit <- lm(reformulate(norm_vars, "priority_citizen", intercept = FALSE), data = d4)
w <- coef(fit)
stopifnot(max(abs(residuals(fit))) < 1e-8, abs(sum(w) - 1) < 1e-8)
w_noexp <- w[setdiff(norm_vars, "norm_green_exp")] / (1 - w["norm_green_exp"])
d4 <- d4 %>%
  mutate(priority_noexp = as.numeric(as.matrix(across(all_of(names(w_noexp)))) %*% w_noexp),
         q5_cur   = priority_citizen >= quantile(priority_citizen, 0.8),
         q5_noexp = priority_noexp >= quantile(priority_noexp, 0.8),
         quint_cur   = ntile(priority_citizen, 5),
         quint_noexp = ntile(priority_noexp, 5))
q4 <- tibble(
  variant = "Without green per person (9 criteria, weights rescaled to sum to 1)",
  weight_green_exp_current = round(w["norm_green_exp"], 4),
  cells_scored = nrow(d4),
  spearman_vs_current = round(cor(d4$priority_citizen, d4$priority_noexp, method = "spearman"), 4),
  top_quintile_cells_current = sum(d4$q5_cur),
  top_quintile_retained_pct = round(100 * sum(d4$q5_cur & d4$q5_noexp) / sum(d4$q5_cur), 1),
  cells_changing_quintile_pct = round(100 * mean(d4$quint_cur != d4$quint_noexp), 1),
  nso_residents_top_quintile_current = round(sum(d4$pop_nso[d4$q5_cur])),
  nso_residents_top_quintile_noexp = round(sum(d4$pop_nso[d4$q5_noexp])))
wcsv(q4, "q4_priority_without_green_per_person.csv")
wcsv(tibble(criterion = names(w), weight_current = round(w, 4),
            weight_without_green_exp = round(c(w_noexp, norm_green_exp = 0)[names(w)], 4)),
     "q4_weights.csv")
print(q4)
print(summary(d4$priority_noexp))
p4 <- ggplot(d4, aes(priority_citizen, priority_noexp)) +
  geom_point(size = 0.3, alpha = 0.3) +
  labs(x = "Current priority score", y = "Priority score without green per person",
       title = sprintf("Spearman r = %.3f; top quintile retained %.1f%%", q4$spearman_vs_current,
                       q4$top_quintile_retained_pct)) +
  theme_minimal(base_size = 9)
ggsave(file.path(OUT, "q4_priority_scatter.png"), p4, width = 140, height = 120, units = "mm", dpi = 200)

# ---- 5. Residents within 5 / 10 min walk of green -------------------------------------------------
d5 <- g %>% st_drop_geometry()
share <- function(popv, thr) 100 * sum(popv[d5$nearest_green_min <= thr], na.rm = TRUE) /
  sum(popv[!is.na(d5$nearest_green_min)])
q5 <- tibble(
  population_layer = c("MCDA Total_Population (Khomenko, DHIR); poster value", "New grid pop_reallocated_nso"),
  pct_within_5min  = round(c(share(d5$Total_Population, 5), share(d5$pop_nso, 5)), 1),
  pct_within_10min = round(c(share(d5$Total_Population, 10), share(d5$pop_nso, 10)), 1),
  residents_without_walk_time = round(c(sum(d5$Total_Population[is.na(d5$nearest_green_min)]),
                                        sum(d5$pop_nso[is.na(d5$nearest_green_min)]))),
  residents_with_walk_time = round(c(sum(d5$Total_Population[!is.na(d5$nearest_green_min)]),
                                     sum(d5$pop_nso[!is.na(d5$nearest_green_min)]))))
wcsv(q5, "q5_residents_within_walk.csv"); print(q5)

# ---- 6. Walking time: ATGreen vs accessibility_grid_malta.gpkg; unroutable vs "no score" ----------
j6 <- acc %>% st_drop_geometry() %>% transmute(gid = as.character(gid), t_gpkg_sec = nearest_green_min * 60) %>%
  full_join(atg %>% select(gid, nearest_green_sec, assignment_status), by = "gid")
both <- filter(j6, !is.na(t_gpkg_sec), !is.na(nearest_green_sec))
q6a <- tibble(cells_gpkg = nrow(acc), cells_atgreen = nrow(atg), cells_both_with_time = nrow(both),
              max_abs_diff_sec = max(abs(both$t_gpkg_sec - both$nearest_green_sec)),
              na_in_gpkg = sum(is.na(j6$t_gpkg_sec)),
              na_in_gpkg_but_time_in_atgreen = sum(is.na(j6$t_gpkg_sec) & !is.na(j6$nearest_green_sec)),
              time_in_gpkg_but_na_in_atgreen = sum(!is.na(j6$t_gpkg_sec) & is.na(j6$nearest_green_sec)))
wcsv(q6a, "q6_walk_time_match.csv"); print(q6a)

d6 <- g %>% st_drop_geometry() %>%
  left_join(atg %>% select(gid, assignment_status), by = "gid") %>%
  mutate(atg_status = coalesce(assignment_status, "not in ATGreen (40 cells)"),
         no_score = is.na(priority_citizen))
q6b <- d6 %>% count(atg_status, no_score) %>% pivot_wider(names_from = no_score, values_from = n, values_fill = 0) %>%
  rename(with_score = `FALSE`, no_score = `TRUE`)
# Which criteria are missing in the "no score" cells
q6c <- d6 %>% filter(no_score) %>%
  summarise(cells = n(), across(all_of(norm_vars), ~ sum(is.na(.)), .names = "na_{.col}"))
q6d <- d6 %>% filter(no_score) %>%
  mutate(missing = apply(is.na(across(all_of(norm_vars))), 1, function(r) paste(sub("norm_", "", norm_vars[r]), collapse = "+"))) %>%
  count(atg_status, missing, sort = TRUE)
wcsv(q6b, "q6_unroutable_vs_no_score.csv"); wcsv(q6c, "q6_no_score_missing_criteria.csv")
wcsv(q6d, "q6_no_score_missing_by_status.csv")
print(q6b); print(q6c); print(q6d)

# ---- 7. Connector cells, Malta and Klagenfurt -----------------------------------------------------
kl <- rd_pq("output/accessibility/outputs-accesibility/klagenfurt/new/klagenfurt_nearest_ua2021/results/unit_network_assignment.parquet")
klg <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")) %>% st_drop_geometry()
conn <- function(st, cm, city, routing, grid_cells) {
  tibble(city = city, routing = routing, grid_cells_study = grid_cells, atgreen_units = length(st),
         direct = sum(st == "direct"), connector = sum(st == "connector"), unroutable = sum(st == "unroutable"),
         connector_pct = round(100 * mean(st == "connector"), 1),
         unroutable_pct = round(100 * mean(st == "unroutable"), 1),
         connector_median_m = round(median(cm[st == "connector"], na.rm = TRUE), 1),
         connector_p95_m = round(quantile(cm[st == "connector"], 0.95, na.rm = TRUE), 1),
         connector_max_m = round(max(cm[st == "connector"], na.rm = TRUE), 1))
}
q7 <- bind_rows(conn(atg$assignment_status, atg$connector_m, "Malta", "Valhalla", nrow(g)),
                conn(kl$assignment_status, kl$connector_m, "Klagenfurt", "OSRM", nrow(klg)))
# Population living in connector cells (Malta, new grid)
mc <- g %>% st_drop_geometry() %>% inner_join(atg %>% select(gid, assignment_status), by = "gid")
q7$pct_residents_in_connector_cells <- c(round(100 * sum(mc$pop_nso[mc$assignment_status == "connector"]) / sum(mc$pop_nso), 1), NA)
wcsv(q7, "q7_connector_cells.csv"); print(q7)

cat("\nAll outputs in", OUT, "\n")
