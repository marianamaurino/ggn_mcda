# Test: Urban Atlas class 32000 (herbaceous vegetation) in the green space definition (2026-11-20)
#
# Malta and Klagenfurt currently disagree on 32000:
#   - Malta: excluded (ATGreen config: 14110, 14130, 31000, 40000). Walking time (ATGreen routing)
#     and green per person (own E2SFCA, mcda/malta_e2sfca_newpop.R) both use 106 green urban areas.
#   - Klagenfurt: included. The MCDA walking time is ATGreen's nearest_green_sec computed with all
#     UA 2021 green classes it extracted (14110, 14130, 31000, 32000: 277 patches, 7 of them 32000).
#     Klagenfurt has no green per person criterion.
#
# Part A (Malta): ADD 32000. Own routing (same OSM network, origins, aggregation and kernel as
#   malta_e2sfca_newpop.R) with the 106 patches vs the 106 patches + UA 2021 32000 polygons
#   (>= 500 m2, selected with ATGreen's spatial rule, checked below). Effect on walking time,
#   green per person, and the priority score.
# Part B (Klagenfurt): DROP 32000. Walking time from own routing with and without 32000
#   (already computed by klagenfurt_e2sfca_newpop.R) and effect on the priority score.
#
# The MCDA files are not modified. Scores are recomputed with the notebooks' formulas (current
# normalisations, available weight rule 80%, citizen weights recovered from the saved score).
# Outputs: output/figures_mcda/green_class_32000_test/
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 nice -n 10 Rscript mcda/green_class_32000_test.R

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(sf); library(arrow); library(igraph); library(ggplot2)
})
OUT <- here::here("output/figures_mcda/green_class_32000_test")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
wcsv <- function(x, f) readr::write_csv(x, file.path(OUT, f))
WALK_M_PER_MIN <- 5000 / 60
wkb_sf <- function(d, crs = 3035) st_sf(d %>% select(-geometry),
                                        geometry = st_as_sfc(structure(as.list(d$geometry), class = "WKB"), crs = crs))
normalize_minmax <- function(x, lower, upper) (pmax(pmin(x, upper), lower) - lower) / (upper - lower)

# Score helpers (same as compute-wlc in both MCDA notebooks)
crit_mat <- function(df, w) as.matrix(as.data.frame(df)[, names(w), drop = FALSE])
wlc_avail <- function(df, w, eligible = rep(TRUE, nrow(df))) {
  S <- crit_mat(df, w); A <- !is.na(S); S[!A] <- 0
  den <- as.numeric(A %*% w)
  out <- as.numeric(S %*% w) / den
  out[den / sum(w) < 0.80 - 1e-12 | !eligible] <- NA
  out
}
# Citizen weights: on complete scored cells the score is exactly sum(w_i s_i)
recover_weights <- function(df, vars, score) {
  cc <- df[complete.cases(as.data.frame(df)[, vars]) & !is.na(df[[score]]), ]
  fit <- lm(reformulate(vars, score, intercept = FALSE), data = cc)
  stopifnot(max(abs(residuals(fit))) < 1e-8)
  coef(fit)
}
# Compare a variant score with a reference on cells scored in both (quintiles within the set)
cmp_score <- function(x, ref, pop) {
  ok <- !is.na(x) & !is.na(ref)
  qx <- ntile(x[ok], 5); qr <- ntile(ref[ok], 5)
  tibble(cells_both = sum(ok),
         spearman = cor(x[ok], ref[ok], method = "spearman"),
         top_quintile_retained_pct = 100 * mean(qx[qr == 5] == 5),
         cells_changing_quintile_pct = 100 * mean(qx != qr),
         residents_top_quintile = sum(pop[ok][qx == 5], na.rm = TRUE),
         residents_top_quintile_ref = sum(pop[ok][qr == 5], na.rm = TRUE))
}

# ==================================================================================================
# Part A. Malta: add 32000
# ==================================================================================================
cat("\n===== Part A: Malta, adding 32000 =====\n")
ATG  <- here::here("accessibility_schifanella/exposure")
DOWN <- here::here("data/malta/accessibility_malta/own_routing")
fm   <- read_parquet(file.path(ATG, "results/final_metrics.parquet")) %>% as.data.frame()
orig <- wkb_sf(read_parquet(file.path(ATG, "results/metrics_origins.parquet")) %>% as.data.frame(),
               crs = 32633) %>% st_transform(3035)
g106 <- wkb_sf(read_parquet(file.path(ATG, "intermediate/green/green_urban_atlas.parquet")) %>% as.data.frame())
pop  <- st_read(here::here("data/malta/Population_Malta_reallocated_nso.gpkg"), quiet = TRUE)
m    <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds"))
saved_own <- readr::read_csv(file.path(DOWN, "e2sfca_own_routing_cells_pre_nov20.csv"), show_col_types = FALSE) %>%
  mutate(gid = as.character(gid))

cells <- fm %>% wkb_sf() %>%
  transmute(gid = as.character(unit_id), assignment_status, connector_sec) %>%
  left_join(pop %>% st_drop_geometry() %>% transmute(gid = as.character(gid), pop_nso = pop_reallocated_nso),
            by = "gid")
cell_union <- st_union(st_geometry(cells))

# ---- A1. 32000 patches, selected with ATGreen's rule ----------------------------------------------
# ATGreen keeps UA polygons >= 500 m2 within its analysis buffer (15 min walk, about 1 km) around
# the study area. Check: the same rule applied to raw 14110/14130 must return exactly its 106 patches.
ua <- st_read(here::here("data/urban_atlas/Malta_UA21/CLMS_UA_LCU_S2021_V025ha_MT001L1_VALLETTA_03035_V01_R00_20241025.fgb"),
              quiet = TRUE) %>%
  filter(code_2021 %in% c("14110", "14130", "31000", "32000", "40000")) %>%
  st_make_valid() %>%
  mutate(a = as.numeric(st_area(geometry)), d_aoi = as.numeric(st_distance(geometry, cell_union)))
BUF_M <- 1100
sel14 <- ua %>% filter(code_2021 %in% c("14110", "14130"), a >= 500, d_aoi <= BUF_M)
hit <- lengths(st_intersects(st_point_on_surface(st_geometry(sel14)), g106)) > 0
cat("Rule check: raw 14110/14130 >= 500 m2 within", BUF_M, "m:", nrow(sel14), "| matched to ATGreen's 106:",
    sum(hit), "\n")
stopifnot(nrow(sel14) == nrow(g106), all(hit))
cat("Forest/wetland polygons within the buffer:",
    sum(ua$code_2021 %in% c("31000", "40000") & ua$d_aoi <= BUF_M), "\n")

p32 <- ua %>% filter(code_2021 == "32000", a >= 500, d_aoi <= BUF_M) %>%
  transmute(green_id = paste0("ua32000_", row_number()), green_ha = a / 1e4, ua_code = "32000")
green <- rbind(g106 %>% transmute(green_id, green_ha, ua_code) %>% st_set_geometry("geometry"),
               p32 %>% st_set_geometry("geometry"))
is32 <- green$ua_code == "32000"
patch_tab <- green %>% st_drop_geometry() %>% group_by(ua_code) %>%
  summarise(patches = n(), ha = round(sum(green_ha), 1), median_ha = round(median(green_ha), 2),
            max_ha = round(max(green_ha), 1), .groups = "drop")
print(as.data.frame(patch_tab)); wcsv(patch_tab, "malta_patches_by_class.csv")

# ---- A2. Walking network (as malta_e2sfca_newpop.R) -----------------------------------------------
hw <- st_read(file.path(DOWN, "osm_highways_raw.gpkg"), quiet = TRUE)
drop_hw <- "^(motorway|motorway_link|construction|proposed|raceway|cycleway|bus_guideway|busway|abandoned|planned|platform|razed|no)$"
walk <- hw %>%
  filter(!grepl(drop_hw, highway), is.na(foot) | foot != "no", is.na(access) | access != "private",
         is.na(service) | service != "private", is.na(area) | area != "yes") %>%
  st_transform(3035) %>% st_cast("LINESTRING", warn = FALSE) %>%
  st_segmentize(dfMaxLength = 20)
xy <- st_coordinates(walk)
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
nodes_sf <- st_sf(id = lcc, geometry = st_sfc(lapply(lcc, function(i) st_point(nodes_xy[i, ])), crs = 3035))

orig$node <- nodes_sf$id[st_nearest_feature(orig, nodes_sf)]
acc <- st_is_within_distance(green, nodes_sf, dist = 20)
no_acc <- which(lengths(acc) == 0)
for (j in no_acc) acc[[j]] <- st_nearest_feature(green[j, ], nodes_sf)
cat("patches without a node within 20 m (nearest node used):", length(no_acc), "of", nrow(green),
    "(32000:", sum(is32[no_acc]), ")\n")

nv <- nrow(nodes_xy); virt <- nv + seq_len(nrow(green))
ed <- rbind(data.frame(from = e$from, to = e$to, w = e$len / WALK_M_PER_MIN),
            data.frame(from = e$to, to = e$from, w = e$len / WALK_M_PER_MIN),
            do.call(rbind, lapply(seq_len(nrow(green)), function(j)
              data.frame(from = virt[j], to = nodes_sf$id[acc[[j]]], w = 0))))
gd <- graph_from_data_frame(ed, directed = TRUE, vertices = data.frame(name = seq_len(nv + nrow(green))))
onodes <- sort(unique(orig$node))
Tm <- distances(gd, v = virt, to = onodes, mode = "out", weights = ed$w)
Tp <- t(Tm)[match(orig$node, onodes), , drop = FALSE]
rm(Tm); invisible(gc())
cat("time matrix", nrow(Tp), "x", ncol(Tp), "\n")

# ---- A3. Cell to patch times, nearest green, E2SFCA -----------------------------------------------
nn <- st_nearest_feature(cells, orig)
inside <- st_join(orig %>% select(network_point_id), cells %>% select(gid), join = st_within)
pts_by_cell <- split(match(inside$network_point_id, orig$network_point_id), inside$gid)
cell_pts <- lapply(seq_len(nrow(cells)), function(i) {
  if (cells$assignment_status[i] == "direct") {
    p <- pts_by_cell[[cells$gid[i]]]; if (length(p) == 0) p <- nn[i]; p
  } else if (cells$assignment_status[i] == "connector") nn[i] else integer(0)
})
conn_min <- ifelse(cells$assignment_status == "connector", cells$connector_sec / 60, 0)
cell_T <- t(vapply(seq_len(nrow(cells)), function(i) {
  p <- cell_pts[[i]]
  if (length(p) == 0) return(rep(NA_real_, ncol(Tp)))
  colMeans(Tp[p, , drop = FALSE]) + conn_min[i]
}, numeric(ncol(Tp))))
nearest_min <- function(cols) {
  pt <- apply(Tp[, cols, drop = FALSE], 1, min)
  vapply(seq_len(nrow(cells)), function(i) {
    p <- cell_pts[[i]]; if (length(p) == 0) NA_real_ else mean(pt[p]) + conn_min[i]
  }, numeric(1))
}
w_gauss <- function(t, sigma = 5, cut = 15) ifelse(t <= cut, exp(-t^2 / (2 * sigma^2)), 0)
e2sfca <- function(P, cols) {
  Wm <- w_gauss(cell_T[, cols, drop = FALSE]); Wm[is.na(Wm)] <- 0
  S <- green$green_ha[cols] * 1e4
  D <- colSums(Wm * P, na.rm = TRUE)
  R <- ifelse(D > 0, S / D, 0)
  out <- as.numeric(Wm %*% R)
  out[cells$assignment_status == "unroutable"] <- NA
  out
}
P <- tidyr::replace_na(cells$pop_nso, 0)
cells <- cells %>% mutate(
  walk_base  = nearest_min(!is32),
  walk_32000 = nearest_min(rep(TRUE, nrow(green))),
  nearest_is_32000 = walk_32000 < walk_base - 1e-9,
  gpp_base   = e2sfca(P, !is32),
  gpp_32000  = e2sfca(P, rep(TRUE, nrow(green))))

# Validation: the base run must reproduce the saved own routing (malta_e2sfca_newpop.R)
vchk <- cells %>% st_drop_geometry() %>% select(gid, walk_base, gpp_base) %>%
  inner_join(saved_own %>% select(gid, own_nearest_sec, own_gauss_nso), by = "gid")
d_walk <- max(abs(vchk$walk_base * 60 - vchk$own_nearest_sec), na.rm = TRUE)
d_gpp  <- max(abs(vchk$gpp_base - vchk$own_gauss_nso), na.rm = TRUE)
cat("Reproduction of saved own routing: max |diff| walking time (s)", signif(d_walk, 3),
    "| green per person (m2)", signif(d_gpp, 3), "\n")
stopifnot(d_walk < 1e-6, d_gpp < 1e-6)

# ---- A4. Indicator comparison ---------------------------------------------------------------------
pp <- cells$pop_nso > 0 & !is.na(cells$pop_nso)
ind_row <- function(label, w, g) {
  ok <- pp & is.finite(w)
  tibble(version = label,
         walk_median_min_residents = {   # population weighted median
           o <- order(w[ok]); cw <- cumsum(P[ok][o]) / sum(P[ok]); w[ok][o][which(cw >= 0.5)[1]] },
         residents_within_5min_pct = 100 * sum(P[ok & w <= 5]) / sum(P[ok]),
         residents_within_10min_pct = 100 * sum(P[ok & w <= 10]) / sum(P[ok]),
         gpp_median_populated = median(g[pp], na.rm = TRUE))
}
ind <- bind_rows(ind_row("Green urban areas only (base, own routing)", cells$walk_base, cells$gpp_base),
                 ind_row("Green urban areas + 32000", cells$walk_32000, cells$gpp_32000)) %>%
  mutate(across(where(is.double), ~ round(., 2)))
okw <- is.finite(cells$walk_base) & is.finite(cells$walk_32000)
okg <- pp & is.finite(cells$gpp_base) & is.finite(cells$gpp_32000)
ind_cor <- tibble(
  check = c("Spearman walking time, base vs +32000 (routed cells)",
            "Spearman green per person, base vs +32000 (populated routed cells)",
            "Routed cells whose nearest green becomes a 32000 patch (%)",
            "Residents whose nearest green becomes a 32000 patch (%)"),
  value = c(cor(cells$walk_base[okw], cells$walk_32000[okw], method = "spearman"),
            cor(cells$gpp_base[okg], cells$gpp_32000[okg], method = "spearman"),
            100 * mean(cells$nearest_is_32000[okw]),
            100 * sum(P[okw & cells$nearest_is_32000]) / sum(P[okw]))) %>% mutate(value = round(value, 3))
print(as.data.frame(ind)); print(as.data.frame(ind_cor))
wcsv(ind, "malta_indicators.csv"); wcsv(ind_cor, "malta_indicator_correlations.csv")
cat("\nwalk_32000 (min):\n"); print(summary(cells$walk_32000))
cat("gpp_32000 (m2 per person, populated cells):\n"); print(summary(cells$gpp_32000[pp]))

# ---- A5. Priority score ---------------------------------------------------------------------------
norm_vars_m <- c("norm_lst", "norm_imd", "norm_dist_bs", "norm_Lden", "norm_traffic", "norm_no2",
                 "norm_tree", "norm_green_time", "norm_dist_rec", "norm_green_exp")
norm_gpp_log <- function(x, populated, eligible) {        # as in the Malta notebook (normalization)
  lx <- ifelse(!is.na(x) & x > 0, log10(x), NA_real_)
  ref <- populated & eligible
  lo <- quantile(lx[ref], 0.02, na.rm = TRUE); hi <- quantile(lx[ref], 0.98, na.rm = TRUE)
  out <- case_when(is.na(x) ~ NA_real_, x == 0 ~ 1, TRUE ~ 1 - (pmin(pmax(lx, lo), hi) - lo) / (hi - lo))
  out[!populated] <- NA_real_
  out
}
norm_walk <- function(x) normalize_minmax(x, 0, quantile(x, 0.98, na.rm = TRUE))

md <- m %>% st_drop_geometry() %>% mutate(gid = as.character(gid)) %>%
  left_join(cells %>% st_drop_geometry() %>% select(gid, walk_base, walk_32000, gpp_base, gpp_32000), by = "gid")
populated <- md$Total_Population > 0; eligible <- !md$ua_not_eligible
w_m <- recover_weights(md, norm_vars_m, "priority_citizen")
# Checks: saved inputs reproduce the saved normalisations and score
stopifnot(max(abs(norm_walk(md$nearest_green_min) - md$norm_green_time), na.rm = TRUE) < 1e-9,
          max(abs(norm_gpp_log(md$green_m2_e2sfca_per_person_gauss, populated, eligible) - md$norm_green_exp),
              na.rm = TRUE) < 1e-9,
          max(abs(wlc_avail(md, w_m, eligible) - md$priority_citizen), na.rm = TRUE) < 1e-9,
          identical(is.na(wlc_avail(md, w_m, eligible)), is.na(md$priority_citizen)))
# Own base gpp equals the score's input (both from malta_e2sfca_newpop.R)
stopifnot(max(abs(md$gpp_base - md$green_m2_e2sfca_per_person_gauss), na.rm = TRUE) < 1e-6)

score_m <- function(walk, gpp) wlc_avail(md %>% mutate(norm_green_time = norm_walk(walk),
                                                       norm_green_exp = norm_gpp_log(gpp, populated, eligible)),
                                         w_m, eligible)
vm <- list(
  "M0 Current score (ATGreen walking time, own green per person)" = md$priority_citizen,
  "M1 Own routing walking time, no 32000 (method check)"          = score_m(md$walk_base, md$gpp_base),
  "M2 + 32000 in walking time only"                               = score_m(md$walk_32000, md$gpp_base),
  "M3 + 32000 in green per person only"                           = score_m(md$walk_base, md$gpp_32000),
  "M4 + 32000 in both"                                            = score_m(md$walk_32000, md$gpp_32000))
pop_m <- md$Total_Population
q_m <- bind_rows(lapply(names(vm), function(v) bind_rows(
  cmp_score(vm[[v]], vm[[1]], pop_m) %>% mutate(reference = "M0 current"),
  cmp_score(vm[[v]], vm[[2]], pop_m) %>% mutate(reference = "M1 own routing, no 32000")) %>%
    mutate(variant = v, cells_scored = sum(!is.na(vm[[v]]))))) %>%
  select(variant, reference, everything()) %>% mutate(across(where(is.double), ~ round(., 3)))
print(as.data.frame(q_m)); wcsv(q_m, "malta_score_comparison.csv")

# Effective weight of the two green criteria (share of score variance, as in the CHANGELOG)
eff_w <- function(walk, gpp) {
  d <- md %>% mutate(norm_green_time = norm_walk(walk), norm_green_exp = norm_gpp_log(gpp, populated, eligible)) %>%
    filter(!is.na(wlc_avail(., w_m, eligible)))
  sds <- sapply(norm_vars_m, function(v) sd(d[[v]], na.rm = TRUE)) * w_m
  round(100 * sds[c("norm_green_time", "norm_green_exp")] / sum(sds), 1)
}
effw <- rbind("M1 no 32000" = eff_w(md$walk_base, md$gpp_base), "M4 + 32000" = eff_w(md$walk_32000, md$gpp_32000),
              citizen_weight_pct = round(100 * w_m[c("norm_green_time", "norm_green_exp")], 1))
cat("\nWeight share (% of sum of w_i * sd_i) of the green criteria:\n"); print(effw)
wcsv(as_tibble(effw, rownames = "version"), "malta_green_criteria_weight_share.csv")

# ---- A6. Maps and histograms ----------------------------------------------------------------------
bb <- st_bbox(cell_union)
pmap <- ggplot() +
  geom_sf(data = cell_union, fill = "grey95", colour = NA) +
  geom_sf(data = green %>% mutate(class = ifelse(is32, "32000 herbaceous", "Green urban areas (14110, 14130)")),
          aes(fill = class), colour = NA) +
  scale_fill_manual(values = c("32000 herbaceous" = "#d8b365", "Green urban areas (14110, 14130)" = "#1b7837"), name = NULL) +
  coord_sf(xlim = bb[c(1, 3)], ylim = bb[c(2, 4)]) + theme_void(base_size = 9) + theme(legend.position = "bottom")
ggsave(file.path(OUT, "malta_patches_map.png"), pmap, width = 160, height = 140, units = "mm", dpi = 200)

p98w <- quantile(cells$walk_base, 0.98, na.rm = TRUE)
mw <- cells %>% select(walk_base, walk_32000) %>% pivot_longer(-geometry) %>%
  mutate(name = recode(name, walk_base = "Green urban areas only", walk_32000 = "+ 32000 herbaceous"))
pw <- ggplot(mw) + geom_sf(aes(fill = pmin(value, p98w)), colour = NA) + facet_wrap(~ name) +
  scale_fill_viridis_c(name = "min (capped\nat base p98)", na.value = "grey85", direction = -1) + theme_void(base_size = 9)
ggsave(file.path(OUT, "malta_walking_time_map.png"), pw, width = 220, height = 110, units = "mm", dpi = 200)

mg <- cells %>% mutate(across(c(gpp_base, gpp_32000), ~ ifelse(pp, log10(pmax(., 0.01)), NA))) %>%
  select(gpp_base, gpp_32000) %>% pivot_longer(-geometry) %>%
  mutate(name = recode(name, gpp_base = "Green urban areas only", gpp_32000 = "+ 32000 herbaceous"))
pg <- ggplot(mg) + geom_sf(aes(fill = value), colour = NA) + facet_wrap(~ name) +
  scale_fill_viridis_c(name = "log10 m2\nper person", na.value = "grey85") + theme_void(base_size = 9)
ggsave(file.path(OUT, "malta_green_per_person_map.png"), pg, width = 220, height = 110, units = "mm", dpi = 200)

hh <- bind_rows(tibble(v = cells$walk_base, version = "Green urban areas only"),
                tibble(v = cells$walk_32000, version = "+ 32000 herbaceous")) %>% filter(is.finite(v))
ph <- ggplot(hh, aes(pmin(v, 30), fill = version)) + geom_histogram(bins = 60, position = "identity", alpha = 0.5) +
  theme_minimal(base_size = 9) + labs(x = "Walking time to nearest green (min, capped at 30)", y = "Cells", fill = NULL)
ggsave(file.path(OUT, "malta_walking_time_histogram.png"), ph, width = 150, height = 90, units = "mm", dpi = 200)

qq <- md %>% transmute(gid, ok = !is.na(vm[[2]]) & !is.na(vm[[5]]))
qq$q1 <- NA; qq$q4 <- NA
qq$q1[qq$ok] <- ntile(vm[[2]][qq$ok], 5); qq$q4[qq$ok] <- ntile(vm[[5]][qq$ok], 5)
mq <- m %>% mutate(gid = as.character(gid)) %>% select(gid) %>% left_join(qq, by = "gid") %>%
  mutate(change = factor(ifelse(ok, pmax(pmin(q4 - q1, 2), -2), NA), levels = -2:2,
                         labels = c("-2 or more", "-1", "0", "+1", "+2 or more")))
pq <- ggplot(mq) + geom_sf(aes(fill = change), colour = NA) +
  scale_fill_manual(values = c("#2166ac", "#92c5de", "grey90", "#f4a582", "#b2182b"), na.value = "white",
                    name = "Quintile change\n(+32000 minus no 32000)", drop = FALSE) + theme_void(base_size = 9)
ggsave(file.path(OUT, "malta_quintile_change_map.png"), pq, width = 160, height = 140, units = "mm", dpi = 200)

readr::write_csv(cells %>% st_drop_geometry() %>%
                   select(gid, assignment_status, pop_nso, walk_base, walk_32000, nearest_is_32000, gpp_base, gpp_32000),
                 file.path(OUT, "malta_cells.csv"))
rm(Tp, cell_T); invisible(gc())

# ==================================================================================================
# Part B. Klagenfurt: drop 32000
# ==================================================================================================
cat("\n===== Part B: Klagenfurt, dropping 32000 =====\n")
k <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds"))
stopifnot(nrow(k) == 12418, !anyDuplicated(k$ID))
kown <- readr::read_csv(here::here("data/klagenfurt/accessibility_klagenfurt/own_routing/e2sfca_own_routing_cells_pre_nov20.csv"),
                        show_col_types = FALSE) %>%
  transmute(ID = as.character(gid), walk_atg_classes = own_nearest_min_atgclasses,
            walk_no32000 = own_nearest_min_500m2)
kd <- k %>% st_drop_geometry() %>% mutate(ID = as.character(ID)) %>% left_join(kown, by = "ID")
norm_vars_k <- c("norm_lst", "norm_dist_bs", "norm_no2", "norm_pm25", "norm_green_time",
                 "norm_traffic_cat", "norm_income_weighted")
w_k <- recover_weights(kd, norm_vars_k, "priority_citizen")
stopifnot(max(abs(norm_walk(kd$nearest_green_min) - kd$norm_green_time), na.rm = TRUE) < 1e-9,
          max(abs(wlc_avail(kd, w_k) - kd$priority_citizen), na.rm = TRUE) < 1e-9,
          identical(is.na(wlc_avail(kd, w_k)), is.na(kd$priority_citizen)))

okk <- is.finite(kd$walk_atg_classes) & is.finite(kd$walk_no32000)
chg <- okk & kd$walk_no32000 > kd$walk_atg_classes + 1e-9
Pk <- tidyr::replace_na(kd$popdense_2020, 0)
k_ind <- tibble(
  check = c("Routed cells", "Cells whose walking time increases when 32000 is dropped (%)",
            "Residents in those cells (%)", "Median increase in those cells (min)",
            "Max increase (min)", "Spearman walking time, with vs without 32000",
            "Spearman walking time, own routing (with 32000) vs ATGreen (current input)"),
  value = c(sum(okk), 100 * mean(chg[okk]), 100 * sum(Pk[chg]) / sum(Pk[okk]),
            median((kd$walk_no32000 - kd$walk_atg_classes)[chg]), max((kd$walk_no32000 - kd$walk_atg_classes)[okk]),
            cor(kd$walk_atg_classes[okk], kd$walk_no32000[okk], method = "spearman"),
            cor(kd$walk_atg_classes, kd$nearest_green_min, method = "spearman", use = "complete.obs"))) %>%
  mutate(value = round(value, 3))
print(as.data.frame(k_ind)); wcsv(k_ind, "klagenfurt_walking_time_change.csv")
cat("walk_no32000 (min):\n"); print(summary(kd$walk_no32000))

score_k <- function(walk) wlc_avail(kd %>% mutate(norm_green_time = norm_walk(walk)), w_k)
vk <- list(
  "K0 Current score (ATGreen walking time, with 32000)"   = kd$priority_citizen,
  "K1 Own routing, with 32000 (method check)"             = score_k(kd$walk_atg_classes),
  "K2 Own routing, without 32000 (Malta classes)"         = score_k(kd$walk_no32000))
q_k <- bind_rows(lapply(names(vk), function(v) bind_rows(
  cmp_score(vk[[v]], vk[[1]], Pk) %>% mutate(reference = "K0 current"),
  cmp_score(vk[[v]], vk[[2]], Pk) %>% mutate(reference = "K1 own routing, with 32000")) %>%
    mutate(variant = v, cells_scored = sum(!is.na(vk[[v]]))))) %>%
  select(variant, reference, everything()) %>% mutate(across(where(is.double), ~ round(., 3)))
print(as.data.frame(q_k)); wcsv(q_k, "klagenfurt_score_comparison.csv")

hk <- k %>% mutate(ID = as.character(ID)) %>% select(ID) %>%
  left_join(kd %>% transmute(ID, increase = ifelse(okk, walk_no32000 - walk_atg_classes, NA)), by = "ID")
pk <- ggplot(hk) + geom_sf(aes(fill = ifelse(increase > 1e-9, increase, NA)), colour = NA) +
  scale_fill_viridis_c(name = "Increase in\nwalking time (min)", na.value = "grey90", option = "inferno", direction = -1) +
  theme_void(base_size = 9)
ggsave(file.path(OUT, "klagenfurt_walking_time_increase_map.png"), pk, width = 160, height = 140, units = "mm", dpi = 200)

cat("\nDone. Outputs in", OUT, "\n")
