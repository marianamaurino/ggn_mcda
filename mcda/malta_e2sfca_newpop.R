# Malta: rebuild ATGreen's E2SFCA green per person with the new population grid
# (GHSL reallocated to residential cells, rescaled to NSO Census 2021; total 346,005).
#
# Why: ATGreen (R. Schifanella, run 2026-06-01) computed the indicator with its own GHSL 2020 3ss
# population and saved no cell-to-green travel times, so it cannot be redone from its outputs
# (output/figures_mcda/atgreen_checks/atgreen_checks_report.md, question 3).
#
# What is reused from ATGreen: the 106 Urban Atlas 2021 green patches (classes 14110, 14130, 31000,
# 40000, >= 500 m2), the 25,299 network origin points, the cell to point assignment and connector
# times. What is new: the walking network (OpenStreetMap, downloaded 2026-11-05) and the routing
# (igraph Dijkstra, 5 km/h) instead of Valhalla.
#
# Validation before use: (a) walking time to nearest green vs ATGreen nearest_green_sec;
# (b) E2SFCA computed with ATGreen's own population vs ATGreen's values. Only then the new population.
# The MCDA files are not modified; results go to output/figures_mcda/atgreen_checks/ and
# data/malta/accessibility_malta/own_routing/.
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/malta_e2sfca_newpop.R

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(sf); library(arrow); library(igraph); library(ggplot2)
})
OUT  <- here::here("output/figures_mcda/atgreen_checks")
DOWN <- here::here("data/malta/accessibility_malta/own_routing")
ATG  <- here::here("accessibility_schifanella/exposure")
WALK_M_PER_MIN <- 5000 / 60
wcsv <- function(x, f) readr::write_csv(x, file.path(OUT, f))
wkb_sf <- function(d, crs = 3035) st_sf(d %>% select(-geometry),
                                        geometry = st_as_sfc(structure(as.list(d$geometry), class = "WKB"), crs = crs))

# ---- Inputs ---------------------------------------------------------------------------------------
fm    <- read_parquet(file.path(ATG, "results/final_metrics.parquet")) %>% as.data.frame()
# Origins are stored in UTM 33N (EPSG:32633) without CRS metadata; cells and patches in EPSG:3035
orig  <- wkb_sf(read_parquet(file.path(ATG, "results/metrics_origins.parquet")) %>% as.data.frame(),
                crs = 32633) %>% st_transform(3035)
green <- wkb_sf(read_parquet(file.path(ATG, "intermediate/green/green_urban_atlas.parquet")) %>% as.data.frame())
near  <- read_parquet(here::here("accessibility_schifanella/nearest/results/final_metrics.parquet")) %>%
  as.data.frame() %>% transmute(gid = as.character(unit_id), nearest_green_sec)
pop   <- st_read(here::here("data/malta/Population_Malta_reallocated_nso.gpkg"), quiet = TRUE)
m     <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds"))
# CRS check: every saved origin must fall inside an analysis cell
cell_geom <- st_as_sfc(structure(as.list(fm$geometry), class = "WKB"), crs = 3035)
inside_share <- mean(lengths(st_intersects(orig, cell_geom)) > 0)
cat("origins inside an analysis cell:", round(inside_share, 3), "\n")
stopifnot(inside_share > 0.99)

cells <- fm %>% wkb_sf() %>%
  transmute(gid = as.character(unit_id), assignment_status, assigned_sample_id, connector_sec,
            pop_atg = population, atg_gauss = green_m2_e2sfca_per_person_gauss,
            atg_step = green_m2_e2sfca_per_person) %>%
  left_join(near, by = "gid") %>%
  left_join(pop %>% st_drop_geometry() %>% transmute(gid = as.character(gid), pop_nso = pop_reallocated_nso),
            by = "gid")
cat("cells", nrow(cells), "| origins", nrow(orig), "| green patches", nrow(green), "\n")
# assigned_sample_id does not follow the numbering of the saved origins (checked: matched ids lie
# km away from their cell), so the link is spatial: direct cells use the origins inside the cell,
# connector cells the nearest origin (checked against ATGreen connector_m below)
nn <- st_nearest_feature(cells, orig)
cells$pt_idx <- nn
cn <- cells$assignment_status == "connector"
d_cn <- as.numeric(st_distance(st_geometry(orig)[nn[cn]], st_geometry(cells)[cn], by_element = TRUE))
cat("connector cells: distance to nearest origin vs ATGreen connector_m: cor",
    round(cor(d_cn, cells$connector_sec[cn]), 3), "| median abs diff (m)",
    round(median(abs(d_cn - cells$connector_sec[cn] * WALK_M_PER_MIN / 60)), 1), "\n")

# ---- 1. Walking network ---------------------------------------------------------------------------
# Pedestrian filter as OSMnx "walk": drop motorways, construction, proposed, raceways, cycleways,
# areas, foot=no, access=private, service=private
hw <- st_read(file.path(DOWN, "osm_highways_raw.gpkg"), quiet = TRUE)
# Pedestrian filter: mcda/walk_filter.R (since 2026-11-20 keeps ways with explicit foot access,
# e.g. shared foot and cycle paths; foot=no and access=private always dropped)
source(here::here("mcda/walk_filter.R"))
walk_filter_report(hw, file.path(DOWN, "malta"))
walk <- hw[walk_keep(hw), ] %>%
  st_transform(3035) %>% st_cast("LINESTRING", warn = FALSE) %>%
  st_segmentize(dfMaxLength = 20)   # vertices every <= 20 m, so patches and origins find nearby nodes
cat("walkable lines", nrow(walk), "of", nrow(hw), "\n")

xy <- st_coordinates(walk)                    # X, Y, L1 = line index
key <- paste(round(xy[, "X"], 2), round(xy[, "Y"], 2))
node_id <- match(key, unique(key))
nodes_xy <- xy[!duplicated(key), c("X", "Y")]
same_line <- xy[-1, "L1"] == xy[-nrow(xy), "L1"]
e <- data.frame(from = node_id[-nrow(xy)][same_line], to = node_id[-1][same_line])
e$len <- sqrt(rowSums((nodes_xy[e$from, ] - nodes_xy[e$to, ])^2))
e <- e[e$from != e$to, ]
gu <- graph_from_data_frame(e, directed = FALSE, vertices = data.frame(name = seq_len(nrow(nodes_xy))))
comp <- components(gu)
lcc <- which(comp$membership == which.max(comp$csize))
cat("nodes", vcount(gu), "| edges", ecount(gu), "| largest component", length(lcc),
    sprintf("(%.1f%%)\n", 100 * length(lcc) / vcount(gu)))
nodes_sf <- st_sf(id = lcc, geometry = st_sfc(lapply(lcc, function(i) st_point(nodes_xy[i, ])), crs = 3035))

# ---- 2. Snap origins and green patches to the network ---------------------------------------------
o_near <- st_nearest_feature(orig, nodes_sf)
orig$node <- nodes_sf$id[o_near]
orig$snap_m <- as.numeric(st_distance(orig, nodes_sf[o_near, ], by_element = TRUE))
cat("origin snap distance (m):\n"); print(summary(orig$snap_m))

# Access nodes: network nodes within 20 m of the patch (ATGreen green_access_buffer_m = 20);
# patches with none get their nearest node
acc <- st_is_within_distance(green, nodes_sf, dist = 20)
no_acc <- which(lengths(acc) == 0)
for (j in no_acc) acc[[j]] <- st_nearest_feature(green[j, ], nodes_sf)
cat("patches without a node within 20 m (nearest node used):", length(no_acc), "\n")

# Directed graph: streets both ways + one way edges from a virtual node per patch to its access
# nodes, so no route can pass through a patch
nv <- nrow(nodes_xy); virt <- nv + seq_len(nrow(green))
ed <- rbind(data.frame(from = e$from, to = e$to, w = e$len / WALK_M_PER_MIN),
            data.frame(from = e$to, to = e$from, w = e$len / WALK_M_PER_MIN),
            do.call(rbind, lapply(seq_len(nrow(green)), function(j)
              data.frame(from = virt[j], to = nodes_sf$id[acc[[j]]], w = 0))))
gd <- graph_from_data_frame(ed, directed = TRUE, vertices = data.frame(name = seq_len(nv + nrow(green))))
onodes <- sort(unique(orig$node))
Tm <- distances(gd, v = virt, to = onodes, mode = "out", weights = ed$w)   # patches x origin nodes, minutes
Tp <- t(Tm)[match(orig$node, onodes), , drop = FALSE]                    # origin points x patches
colnames(Tp) <- green$green_id
cat("time matrix", dim(Tp)[1], "x", dim(Tp)[2], "| finite share", round(mean(is.finite(Tp)), 3), "\n")

# ---- 3. Cell to patch times (ATGreen aggregation: mean over points in the cell; connector cells
#         use their assigned point + connector time; unroutable cells NA) --------------------------
pt_cell <- st_join(orig %>% select(network_point_id), cells %>% select(gid), join = st_within)
pts_by_cell <- split(match(pt_cell$network_point_id, orig$network_point_id), pt_cell$gid)
cell_pts <- lapply(seq_len(nrow(cells)), function(i) {
  if (cells$assignment_status[i] == "direct") {
    p <- pts_by_cell[[cells$gid[i]]]; if (length(p) == 0) p <- cells$pt_idx[i]; p
  } else if (cells$assignment_status[i] == "connector") cells$pt_idx[i] else integer(0)
})
conn_min <- ifelse(cells$assignment_status == "connector", cells$connector_sec / 60, 0)
# Zero rule (since 2026-11-20, as ATGreen): origin inside a patch -> time 0 to it, and a connector
# cell assigned to that point gets 0 for that patch (no connector walk)
in_green <- matrix(FALSE, nrow(orig), nrow(green))
ig <- st_intersects(orig, green)
for (p in which(lengths(ig) > 0)) in_green[p, ig[[p]]] <- TRUE
cat("origin points inside a green patch:", sum(rowSums(in_green) > 0), "of", nrow(orig), "\n")
Tz <- apply_zero_rule(Tp, in_green)
cell_times <- function(T, zero) t(vapply(seq_len(nrow(cells)), function(i) {
  p <- cell_pts[[i]]
  if (length(p) == 0) return(rep(NA_real_, ncol(T)))
  add <- if (zero && length(p) == 1 && cells$assignment_status[i] == "connector") conn_min[i] * !in_green[p, ] else conn_min[i]
  colMeans(T[p, , drop = FALSE]) + add
}, numeric(ncol(T))))
# Nearest green per point, then mean (and median) per cell
nearest_cell <- function(T, zero, fun = mean) {
  pt <- apply(T, 1, min); pin <- rowSums(in_green) > 0
  vapply(seq_len(nrow(cells)), function(i) {
    p <- cell_pts[[i]]
    if (length(p) == 0) return(NA_real_)
    if (cells$assignment_status[i] == "connector") return(if (zero && pin[p]) 0 else pt[p] + conn_min[i])
    fun(pt[p])
  }, numeric(1))
}
cell_T_nozero <- cell_times(Tp, FALSE)
cell_T        <- cell_times(Tz, TRUE)
cells$own_nearest_sec_nozero <- 60 * nearest_cell(Tp, FALSE)
cells$own_nearest_sec        <- 60 * nearest_cell(Tz, TRUE)
cells$own_nearest_sec_median <- 60 * nearest_cell(Tz, TRUE, median)

# ---- 4. E2SFCA ------------------------------------------------------------------------------------
w_step  <- function(t) ifelse(t <= 5, 1, ifelse(t <= 10, 0.7, ifelse(t <= 15, 0.4, 0)))
# Gaussian kernel: sigma = 5 min, cut at 15 min. Chosen as the closest match to ATGreen's Gaussian
# among 10 kernels tried with ATGreen's population (Spearman 0.978, median 0.50 vs 0.51; see
# e2sfca_kernel_choice.csv); ATGreen's exact kernel is not documented in its outputs
w_gauss <- function(t, sigma = 5, cut = 15) ifelse(t <= cut, exp(-t^2 / (2 * sigma^2)), 0)
S <- green$green_ha * 1e4   # supply: patch area, m2
e2sfca <- function(P, W, CT = cell_T) {
  Wm <- W(CT); Wm[is.na(Wm)] <- 0
  D <- colSums(Wm * P, na.rm = TRUE)        # step 1: weighted population reaching each patch
  R <- ifelse(D > 0, S / D, 0)
  out <- as.numeric(Wm %*% R)               # step 2: sum of patch ratios reachable from the cell
  out[cells$assignment_status == "unroutable"] <- NA
  out
}
cells <- cells %>%
  mutate(own_gauss_atgpop = e2sfca(pop_atg, w_gauss), own_step_atgpop = e2sfca(pop_atg, w_step),
         own_gauss_nso    = e2sfca(pop_nso, w_gauss), own_step_nso    = e2sfca(pop_nso, w_step),
         own_gauss_nso_nozero = e2sfca(pop_nso, w_gauss, cell_T_nozero),
         # Sensitivity, walking speed 4 km/h (spec 5.3): every time is distance / speed, so the
         # 4 km/h times are exactly 5/4 of the 5 km/h times (kernel and cutoff unchanged)
         own_gauss_nso_4kmh = e2sfca(pop_nso, w_gauss, cell_T * 5 / 4))

# ---- 5. Validation --------------------------------------------------------------------------------
vr <- function(x, y, what) {
  ok <- is.finite(x) & is.finite(y)
  tibble(check = what, cells = sum(ok), spearman = cor(x[ok], y[ok], method = "spearman"),
         pearson = cor(x[ok], y[ok]), median_ours = median(x[ok]), median_atgreen = median(y[ok]))
}
val <- bind_rows(
  vr(cells$own_nearest_sec_nozero, cells$nearest_green_sec, "Walking time to nearest green (s), own routing vs ATGreen, no zero rule"),
  vr(cells$own_nearest_sec, cells$nearest_green_sec, "Walking time to nearest green (s), own routing vs ATGreen, zero rule"),
  vr(cells$own_gauss_atgpop, cells$atg_gauss, "E2SFCA Gaussian, ATGreen population: own vs ATGreen"),
  vr(cells$own_step_atgpop, cells$atg_step, "E2SFCA step 1/0.7/0.4, ATGreen population: own vs ATGreen")) %>%
  mutate(across(where(is.double), ~ round(., 3)))
wcsv(val, "e2sfca_rebuild_validation.csv"); print(as.data.frame(val))

# ---- 6. Save cell values --------------------------------------------------------------------------
cell_out <- cells %>% st_drop_geometry() %>%
  select(gid, assignment_status, pop_atg, pop_nso, nearest_green_sec, own_nearest_sec_nozero, own_nearest_sec,
         own_nearest_sec_median, atg_gauss, own_gauss_atgpop, own_gauss_nso_nozero, own_gauss_nso,
         own_gauss_nso_4kmh, atg_step, own_step_atgpop, own_step_nso)
readr::write_csv(cell_out, file.path(DOWN, "e2sfca_own_routing_cells.csv"))
saveRDS(list(Tp = Tp, cell_T = cell_T, in_green = in_green, gid = cells$gid, green_id = green$green_id),
        file.path(DOWN, "travel_times_min.rds"))
cat("\nSaved", file.path(DOWN, "e2sfca_own_routing_cells.csv"), "\n")
# MCDA input (read by Malta_MCDA_260702_realloc.Rmd: gauss and step columns; walking time from
# e2sfca_own_routing_cells.csv). The norm column is the pre-2026-11-19 formula, not used by the score.
readr::write_csv(cells %>% st_drop_geometry() %>%
                   transmute(gid, green_m2_e2sfca_gauss_newpop = own_gauss_nso,
                             green_m2_e2sfca_step_newpop = own_step_nso,
                             green_m2_e2sfca_gauss_newpop_4kmh = own_gauss_nso_4kmh),
                 file.path(DOWN, "norm_green_exp_newpop.csv"))
cat("Saved", file.path(DOWN, "norm_green_exp_newpop.csv"), "\n")

# Section 7 is the 2026-11-05 comparison (ATGreen vs own E2SFCA) with the min max normalisation used
# until 2026-11-19; its check fails against the current log score, so it is not run any more.
# Its outputs (output/figures_mcda/atgreen_checks/e2sfca_*.csv) are kept as a record.
RUN_NOV05_COMPARISON <- FALSE
if (!RUN_NOV05_COMPARISON) quit(save = "no")

# ---- 7. Priority score with the rebuilt indicator -------------------------------------------------
norm_vars <- c("norm_lst", "norm_imd", "norm_dist_bs", "norm_Lden", "norm_traffic", "norm_no2",
               "norm_tree", "norm_green_time", "norm_dist_rec", "norm_green_exp")
normalize_minmax <- function(x, lower, upper) (pmax(pmin(x, upper), lower) - lower) / (upper - lower)
norm_exp <- function(x) tidyr::replace_na(1 - normalize_minmax(x, 0, quantile(x, 0.98, na.rm = TRUE)), 0)

mg <- m %>% st_drop_geometry() %>% mutate(gid = as.character(gid)) %>%
  left_join(cell_out %>% select(gid, atg_gauss, own_gauss_atgpop, own_gauss_nso, own_step_nso), by = "gid")
# Check: the MCDA formula applied to ATGreen's values gives the saved norm_green_exp
stopifnot(max(abs(norm_exp(mg$atg_gauss) - mg$norm_green_exp)) < 1e-9)
sc <- mg %>% filter(!is.na(priority_citizen))
fit <- lm(reformulate(norm_vars, "priority_citizen", intercept = FALSE), data = sc)
w <- coef(fit); stopifnot(max(abs(residuals(fit))) < 1e-8)
others <- as.matrix(sc[, setdiff(norm_vars, "norm_green_exp")]) %*% w[setdiff(norm_vars, "norm_green_exp")]
score_with <- function(ne) as.numeric(others + w["norm_green_exp"] * ne[!is.na(mg$priority_citizen)])
w9 <- w[setdiff(norm_vars, "norm_green_exp")] / (1 - w["norm_green_exp"])
variants <- list(
  "Current (ATGreen routing and population)" = sc$priority_citizen,
  "Own routing, ATGreen population (method check)" = score_with(norm_exp(mg$own_gauss_atgpop)),
  "Own routing, new population (NSO grid), Gaussian" = score_with(norm_exp(mg$own_gauss_nso)),
  "Own routing, new population (NSO grid), step 1/0.7/0.4" = score_with(norm_exp(mg$own_step_nso)),
  "Without green per person (9 criteria)" = as.numeric(as.matrix(sc[, names(w9)]) %*% w9))
cmp_score <- function(x, ref) {
  q5r <- ref >= quantile(ref, 0.8); q5x <- x >= quantile(x, 0.8)
  c(spearman = cor(x, ref, method = "spearman"), top_quintile_retained_pct = 100 * sum(q5r & q5x) / sum(q5r),
    cells_changing_quintile_pct = 100 * mean(ntile(x, 5) != ntile(ref, 5)),
    nso_residents_top_quintile = sum(sc$pop_nso_tmp[q5x]))
}
sc$pop_nso_tmp <- pop$pop_reallocated_nso[match(sc$gid, as.character(pop$gid))]
q_pri <- bind_rows(lapply(names(variants), function(v) {
  a <- cmp_score(variants[[v]], variants[[1]]); b <- cmp_score(variants[[v]], variants[[2]])
  tibble(variant = v, cells = nrow(sc), spearman_vs_current = a["spearman"],
         top_quintile_retained_vs_current_pct = a["top_quintile_retained_pct"],
         cells_changing_quintile_vs_current_pct = a["cells_changing_quintile_pct"],
         spearman_vs_own_routing_atgpop = b["spearman"],
         top_quintile_retained_vs_own_routing_atgpop_pct = b["top_quintile_retained_pct"],
         nso_residents_top_quintile = a["nso_residents_top_quintile"])
})) %>% mutate(across(where(is.double), ~ round(., 3)))
wcsv(q_pri, "e2sfca_priority_comparison.csv"); print(as.data.frame(q_pri))

# Indicator level: new population vs ATGreen
ind <- bind_rows(
  vr(mg$own_gauss_nso, mg$atg_gauss, "E2SFCA Gaussian: own routing + new population vs ATGreen (current input)"),
  vr(mg$own_gauss_nso, mg$own_gauss_atgpop, "E2SFCA Gaussian: new vs ATGreen population, both own routing (population effect)"),
  vr(norm_exp(mg$own_gauss_nso), mg$norm_green_exp, "norm_green_exp: new vs current")) %>%
  mutate(across(where(is.double), ~ round(., 3)))
wcsv(ind, "e2sfca_indicator_comparison.csv"); print(as.data.frame(ind))

# Sanity checks for the new indicator: summary, histogram, map
cat("\nown_gauss_nso (m2 green per person, E2SFCA, new population):\n"); print(summary(mg$own_gauss_nso))
p98 <- quantile(mg$own_gauss_nso, 0.98, na.rm = TRUE)
ph <- ggplot(filter(mg, is.finite(own_gauss_nso)), aes(pmin(own_gauss_nso, p98))) +
  geom_histogram(bins = 60) + theme_minimal(base_size = 9) +
  labs(x = "m2 green per person (E2SFCA Gaussian, new population; capped at p98)", y = "Cells")
ggsave(file.path(OUT, "e2sfca_newpop_histogram.png"), ph, width = 140, height = 90, units = "mm", dpi = 200)
mm <- m %>% mutate(gid = as.character(gid)) %>% select(gid) %>%
  left_join(mg %>% select(gid, atg_gauss, own_gauss_nso), by = "gid") %>%
  pivot_longer(c(atg_gauss, own_gauss_nso), names_to = "version", values_to = "v") %>%
  mutate(version = recode(version, atg_gauss = "ATGreen (current MCDA input)", own_gauss_nso = "Own routing, new population"))
pm <- ggplot(mm) + geom_sf(aes(fill = pmin(v, p98)), colour = NA) + facet_wrap(~ version) +
  scale_fill_viridis_c(name = "m2/person\n(capped p98)", na.value = "grey85") + theme_void(base_size = 9)
ggsave(file.path(OUT, "e2sfca_newpop_map.png"), pm, width = 200, height = 100, units = "mm", dpi = 200)

# Save the rebuilt criterion for the MCDA grid (not written into the MCDA files)
readr::write_csv(mg %>% transmute(gid, green_m2_e2sfca_gauss_newpop = own_gauss_nso,
                                  green_m2_e2sfca_step_newpop = own_step_nso,
                                  norm_green_exp_newpop = norm_exp(own_gauss_nso)),
                 file.path(DOWN, "norm_green_exp_newpop.csv"))
cat("Saved", file.path(DOWN, "norm_green_exp_newpop.csv"), "\n")
