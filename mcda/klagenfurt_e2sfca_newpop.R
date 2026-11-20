# Klagenfurt: own walking routing to Urban Atlas green and E2SFCA green per person with the census
# grid population, built the same way as mcda/malta_e2sfca_newpop.R so both cities are comparable
# (WP6 deck, November 2026).
#
# Why: ATGreen (R. Schifanella) saved only the time to the nearest green patch for Klagenfurt, so
# walking times to green >= 0.5 ha and the E2SFCA step 1/0.7/0.4 could not be derived from its outputs.
#
# Reused from ATGreen (klagenfurt_nearest_ua2021): the Urban Atlas 2021 green patches (>= 500 m2),
# the 21,922 network origin points, the cell assignment (direct / connector / unroutable) and the
# connector times, on the 100 m grid of the MCDA (unit_id = ID).
# New: the OSM walking network (downloaded here with osmdata), igraph Dijkstra at 5 km/h, and the
# green classes restricted to Malta's (14110, 14130, 31000, 40000), i.e. UA 32000 herbaceous
# vegetation (7 patches, included by ATGreen in Klagenfurt) is dropped. Population: census grid
# (popdense_2020 in data/klagenfurt/klagenfurt_mcda_priority_may.rds).
#
# Validation: walking time to nearest green, own routing with ATGreen's classes vs ATGreen
# nearest_green_sec. The MCDA files are not modified. Outputs: data/klagenfurt/accessibility_klagenfurt/own_routing/.
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/klagenfurt_e2sfca_newpop.R

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(sf); library(arrow); library(igraph); library(ggplot2)
})
ATG  <- here::here("output/accessibility/outputs-accesibility/klagenfurt/new/klagenfurt_nearest_ua2021")
DOWN <- here::here("data/klagenfurt/accessibility_klagenfurt/own_routing")
dir.create(DOWN, showWarnings = FALSE, recursive = TRUE)
WALK_M_PER_MIN <- 5000 / 60
MALTA_CLASSES  <- c("14110", "14130", "31000", "40000")
wkb_sf <- function(d, crs = 3035) st_sf(d %>% select(-geometry),
                                        geometry = st_as_sfc(structure(as.list(d$geometry), class = "WKB"), crs = crs))

# ---- Inputs ---------------------------------------------------------------------------------------
fm    <- read_parquet(file.path(ATG, "results/final_metrics.parquet")) %>% as.data.frame()
# Origins in UTM 33N (EPSG:32633) without CRS metadata, as in Malta; cells and patches in EPSG:3035
orig  <- wkb_sf(read_parquet(file.path(ATG, "results/metrics_origins.parquet")) %>% as.data.frame(),
                crs = 32633) %>% st_transform(3035)
green_all <- wkb_sf(read_parquet(file.path(ATG, "intermediate/green/green_urban_atlas.parquet")) %>% as.data.frame())
kl <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")) %>% st_drop_geometry() %>%
  transmute(gid = as.character(ID), pop_census = tidyr::replace_na(popdense_2020, 0)) %>%
  # The MCDA rds repeats 101 cells 2 to 4 times (12,751 rows, 12,418 IDs; copies identical,
  # checked 2026-11-11): keep one row per cell, otherwise residents are double counted
  distinct(gid, .keep_all = TRUE)
stopifnot(!anyDuplicated(kl$gid))

cells <- fm %>% wkb_sf() %>%
  transmute(gid = as.character(unit_id), assignment_status, connector_sec, nearest_green_sec) %>%
  left_join(kl, by = "gid")
cell_geom <- st_geometry(cells)
inside_share <- mean(lengths(st_intersects(orig, cell_geom)) > 0)
cat("origins inside an analysis cell:", round(inside_share, 3), "\n")
stopifnot(inside_share > 0.99)
cat("cells", nrow(cells), "| matched to MCDA grid", sum(!is.na(cells$pop_census)),
    "| census residents on routing cells", round(sum(cells$pop_census, na.rm = TRUE)),
    "of", round(sum(kl$pop_census)), "\n")
cat("green patches", nrow(green_all), "| without 32000:", sum(green_all$ua_code %in% MALTA_CLASSES), "\n")
nn <- st_nearest_feature(cells, orig)
cells$pt_idx <- nn

# ---- 1. Walking network (OSM, downloaded once) ----------------------------------------------------
raw_path <- file.path(DOWN, "osm_highways_raw.gpkg")
if (!file.exists(raw_path)) {
  bb <- st_bbox(st_transform(st_buffer(st_union(st_union(st_geometry(green_all)), st_union(cell_geom)), 1500), 4326))
  q <- osmdata::opq(bbox = as.numeric(bb), timeout = 300) %>% osmdata::add_osm_feature(key = "highway")
  od <- osmdata::osmdata_sf(q)
  keep <- c("osm_id", "highway", "foot", "access", "area", "service", "sidewalk", "name")
  sel <- function(x) { for (k in setdiff(keep, names(x))) x[[k]] <- NA_character_; x[, keep] }
  # osmdata puts closed ways (roundabouts, closed footpaths) in osm_polygons: keep them as lines
  hw_raw <- rbind(sel(od$osm_lines),
                  sel(od$osm_polygons) %>% st_cast("LINESTRING", warn = FALSE))
  hw_raw <- hw_raw %>% filter(!is.na(highway))
  st_write(hw_raw, raw_path, delete_dsn = TRUE, quiet = TRUE)
  cat("OSM highways downloaded", format(Sys.Date()), ":", nrow(hw_raw), "ways\n")
}
hw <- st_read(raw_path, quiet = TRUE)
# Pedestrian filter: mcda/walk_filter.R (since 2026-11-20 keeps ways with explicit foot access,
# e.g. shared foot and cycle paths; foot=no and access=private always dropped)
source(here::here("mcda/walk_filter.R"))
walk_filter_report(hw, file.path(DOWN, "klagenfurt"))
walk <- hw[walk_keep(hw), ] %>%
  st_transform(3035) %>% st_cast("LINESTRING", warn = FALSE) %>%
  st_segmentize(dfMaxLength = 20)
cat("walkable lines", nrow(walk), "of", nrow(hw), "\n")

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
cat("nodes", vcount(gu), "| edges", ecount(gu), "| largest component", length(lcc),
    sprintf("(%.1f%%)\n", 100 * length(lcc) / vcount(gu)))
nodes_sf <- st_sf(id = lcc, geometry = st_sfc(lapply(lcc, function(i) st_point(nodes_xy[i, ])), crs = 3035))

# ---- 2. Snap origins and all ATGreen patches (32000 kept for the validation) ----------------------
o_near <- st_nearest_feature(orig, nodes_sf)
orig$node <- nodes_sf$id[o_near]
orig$snap_m <- as.numeric(st_distance(orig, nodes_sf[o_near, ], by_element = TRUE))
cat("origin snap distance (m):\n"); print(summary(orig$snap_m))

green <- green_all
acc <- st_is_within_distance(green, nodes_sf, dist = 20)
no_acc <- which(lengths(acc) == 0)
for (j in no_acc) acc[[j]] <- st_nearest_feature(green[j, ], nodes_sf)
cat("patches without a node within 20 m (nearest node used):", length(no_acc), "\n")

nv <- nrow(nodes_xy); virt <- nv + seq_len(nrow(green))
ed <- rbind(data.frame(from = e$from, to = e$to, w = e$len / WALK_M_PER_MIN),
            data.frame(from = e$to, to = e$from, w = e$len / WALK_M_PER_MIN),
            do.call(rbind, lapply(seq_len(nrow(green)), function(j)
              data.frame(from = virt[j], to = nodes_sf$id[acc[[j]]], w = 0))))
gd <- graph_from_data_frame(ed, directed = TRUE, vertices = data.frame(name = seq_len(nv + nrow(green))))
onodes <- sort(unique(orig$node))
Tm <- distances(gd, v = virt, to = onodes, mode = "out", weights = ed$w)
Tp <- t(Tm)[match(orig$node, onodes), , drop = FALSE]
colnames(Tp) <- green$green_id
cat("time matrix", dim(Tp)[1], "x", dim(Tp)[2], "| finite share", round(mean(is.finite(Tp)), 3), "\n")

# ---- 3. Cell to patch times and nearest green (ATGreen aggregation, as in Malta) ------------------
inside <- st_join(orig %>% select(network_point_id), cells %>% select(gid), join = st_within)
pts_by_cell <- split(match(inside$network_point_id, orig$network_point_id), inside$gid)
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
is_m <- green$ua_code %in% MALTA_CLASSES
cell_T <- t(vapply(seq_len(nrow(cells)), function(i) {
  p <- cell_pts[[i]]
  if (length(p) == 0) return(rep(NA_real_, ncol(Tz)))
  add <- if (cells$assignment_status[i] == "connector") conn_min[i] * !in_green[p, ] else 0
  colMeans(Tz[p, , drop = FALSE]) + add
}, numeric(ncol(Tz))))
# Nearest green per origin point, then mean (or median) per cell; for a subset of patches
nearest_min <- function(cols, zero = TRUE, fun = mean) {
  T <- if (zero) Tz else Tp
  pt <- apply(T[, cols, drop = FALSE], 1, min)
  pin <- rowSums(in_green[, cols, drop = FALSE]) > 0
  vapply(seq_len(nrow(cells)), function(i) {
    p <- cell_pts[[i]]
    if (length(p) == 0) return(NA_real_)
    if (cells$assignment_status[i] == "connector") return(if (zero && pin[p]) 0 else pt[p] + conn_min[i])
    fun(pt[p])
  }, numeric(1))
}
cells <- cells %>% mutate(
  own_nearest_min_atgclasses = nearest_min(rep(TRUE, nrow(green)), zero = FALSE),   # validation only
  own_nearest_min_atgclasses_zero = nearest_min(rep(TRUE, nrow(green))),            # validation only
  own_nearest_min_nozero     = nearest_min(is_m, zero = FALSE),
  own_nearest_min            = nearest_min(is_m),                  # MCDA input since 2026-11-20
  own_nearest_min_median     = nearest_min(is_m, fun = median),
  own_nearest_min_05ha       = nearest_min(is_m & green$green_ha >= 0.5))

# ---- 4. E2SFCA (Malta classes, census population) ------------------------------------------------
w_step  <- function(t) ifelse(t <= 5, 1, ifelse(t <= 10, 0.7, ifelse(t <= 15, 0.4, 0)))
w_step10 <- function(t) ifelse(t <= 5, 1, ifelse(t <= 10, 0.7, 0))
w_gauss <- function(t, sigma = 5, cut = 15) ifelse(t <= cut, exp(-t^2 / (2 * sigma^2)), 0)
Tm_m <- cell_T[, is_m, drop = FALSE]
S <- green$green_ha[is_m] * 1e4
e2sfca <- function(P, W) {
  Wm <- W(Tm_m); Wm[is.na(Wm)] <- 0
  D <- colSums(Wm * P, na.rm = TRUE)
  R <- ifelse(D > 0, S / D, 0)
  out <- as.numeric(Wm %*% R)
  out[cells$assignment_status == "unroutable"] <- NA
  out
}
P <- tidyr::replace_na(cells$pop_census, 0)
cells <- cells %>% mutate(own_step_census = e2sfca(P, w_step), own_step10_census = e2sfca(P, w_step10),
                          own_gauss_census = e2sfca(P, w_gauss))

# ---- 5. Validation and sanity checks ------------------------------------------------------------
ok <- is.finite(cells$own_nearest_min_atgclasses) & is.finite(cells$nearest_green_sec)
own_t <- cells$own_nearest_min_atgclasses[ok]; atg_t <- cells$nearest_green_sec[ok] / 60
val <- tibble(check = "Walking time to nearest green (min), own routing vs ATGreen, ATGreen classes",
              n_cells = sum(ok),
              spearman = cor(own_t, atg_t, method = "spearman"),
              pearson = cor(own_t, atg_t),
              median_ours = median(own_t),
              median_atgreen = median(atg_t),
              share_same_5min_band = mean(cut(own_t, c(-1, 5, 10, 15, Inf)) == cut(atg_t, c(-1, 5, 10, 15, Inf)))) %>%
  mutate(across(where(is.double), ~ round(., 3)))
print(as.data.frame(val))
readr::write_csv(val, file.path(DOWN, "routing_validation.csv"))

cat("\nown_nearest_min:\n"); print(summary(cells$own_nearest_min))
cat("own_nearest_min_05ha:\n");  print(summary(cells$own_nearest_min_05ha))
cat("own_step_census (m2 green per person, step 1/0.7/0.4):\n"); print(summary(cells$own_step_census))
p98 <- quantile(cells$own_step_census, 0.98, na.rm = TRUE)
ph <- ggplot(filter(cells, is.finite(own_step_census), pop_census > 0), aes(pmin(own_step_census, p98))) +
  geom_histogram(bins = 60) + theme_minimal(base_size = 9) +
  labs(x = "m2 green per person (E2SFCA step 1/0.7/0.4, census population; capped at p98)", y = "Populated cells")
ggsave(file.path(DOWN, "e2sfca_step_census_histogram.png"), ph, width = 140, height = 90, units = "mm", dpi = 200)
pm <- ggplot(cells %>% select(own_nearest_min, own_step_census) %>%
               mutate(own_step_census = pmin(own_step_census, p98)) %>%
               pivot_longer(-geometry)) +
  geom_sf(aes(fill = value), colour = NA) + facet_wrap(~ name) +
  scale_fill_viridis_c(na.value = "grey85") + theme_void(base_size = 9)
ggsave(file.path(DOWN, "own_routing_maps.png"), pm, width = 200, height = 100, units = "mm", dpi = 200)

# ---- 6. Save -----------------------------------------------------------------------------------
readr::write_csv(cells %>% st_drop_geometry() %>%
                   select(gid, assignment_status, pop_census, nearest_green_sec, own_nearest_min_atgclasses,
                          own_nearest_min_atgclasses_zero, own_nearest_min_nozero, own_nearest_min, own_nearest_min_median, own_nearest_min_05ha, own_step_census, own_step10_census,
                          own_gauss_census),
                 file.path(DOWN, "e2sfca_own_routing_cells.csv"))
saveRDS(list(Tp = Tp, cell_T = cell_T, in_green = in_green, gid = cells$gid, green_id = green$green_id,
             ua_code = green$ua_code, green_ha = green$green_ha),
        file.path(DOWN, "travel_times_min.rds"))
cat("\nSaved to", DOWN, "\n")
