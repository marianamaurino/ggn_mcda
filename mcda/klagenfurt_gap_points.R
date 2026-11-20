# Klagenfurt: origin points where our walking time to the nearest green is still >= 3 min longer than
# ATGreen's (OSRM foot profile), after the 2026-11-20 pedestrian filter (military dropped). Report only,
# the filter is not changed here.
#
# Comparison as in the routing validation: ATGreen's 277 patches (incl. 32000), zero rule on both sides,
# origin level. OSRM's own routes are not available (only its times), so the second route drawn is our
# routing on the UNFILTERED download (every highway way): if that closes the gap, the cause is a way
# our filter drops (a).
#
# Causes: (a) a way OSRM uses that our filter drops; (b) a difference between the OSM downloads (ours
# 2026-11-11, OSRM's extract 2026-03-04); (c) the point sits on a piece of network not connected to the
# largest component; (d) something else.
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(sf); library(arrow); library(igraph); library(ggplot2)
})
ATG  <- here::here("output/accessibility/outputs-accesibility/klagenfurt/new/klagenfurt_nearest_ua2021")
DOWN <- here::here("data/klagenfurt/accessibility_klagenfurt/own_routing")
OUT  <- here::here("output/figures_mcda/walk_time_switch_2026_11_20/klagenfurt_gap_points")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
WALK_M_PER_MIN <- 5000 / 60
GAP_MIN <- 3
wkb_sf <- function(d, crs = 3035) st_sf(d %>% select(-geometry),
                                        geometry = st_as_sfc(structure(as.list(d$geometry), class = "WKB"), crs = crs))
source(here::here("mcda/walk_filter.R"))

orig  <- wkb_sf(read_parquet(file.path(ATG, "results/metrics_origins.parquet")) %>% as.data.frame(),
                crs = 32633) %>% st_transform(3035) %>% mutate(atg = nearest_green_sec / 60)
green <- wkb_sf(read_parquet(file.path(ATG, "intermediate/green/green_urban_atlas.parquet")) %>% as.data.frame())
fm    <- wkb_sf(read_parquet(file.path(ATG, "results/final_metrics.parquet")) %>% as.data.frame())
hw    <- st_read(file.path(DOWN, "osm_highways_raw.gpkg"), quiet = TRUE) %>% st_transform(3035)
hw$kept <- walk_keep(hw)
tt    <- readRDS(file.path(DOWN, "travel_times_min.rds"))
stopifnot(nrow(tt$Tp) == nrow(orig), ncol(tt$Tp) == nrow(green), identical(colnames(tt$Tp), as.character(green$green_id)))

# ---- Origin-level comparison (current routing output) ---------------------------------------------
Tz  <- apply_zero_rule(tt$Tp, tt$in_green)
own <- apply(Tz, 1, min)
own_j <- apply(Tz, 1, function(r) if (all(!is.finite(r))) NA_integer_ else which.min(r))
d   <- own - orig$atg
gap <- which(is.finite(d) & d >= GAP_MIN)
cat("origins compared:", sum(is.finite(d)), "| own >= ATGreen +", GAP_MIN, "min:", length(gap),
    "| own <= ATGreen -", GAP_MIN, "min:", sum(is.finite(d) & d <= -GAP_MIN), "\n")
# 2026-11-20 run: 0 points. The 20 of the v2 filter test sat on highway=track + access=no ways, which v2
# kept and the final filter drops (see former_gap_points_access_no_tracks.png in OUT)
if (length(gap) == 0) { cat("No gap points: nothing to diagnose.\n"); quit(save = "no") }

# ---- Graph builder (same construction as mcda/klagenfurt_e2sfca_newpop.R) ---------------------------
build <- function(lines) {
  w <- lines %>% st_transform(3035) %>% st_cast("LINESTRING", warn = FALSE) %>% st_segmentize(dfMaxLength = 20)
  xy <- st_coordinates(w); key <- paste(round(xy[, "X"], 2), round(xy[, "Y"], 2))
  id <- match(key, unique(key)); nxy <- xy[!duplicated(key), c("X", "Y")]
  sl <- xy[-1, "L1"] == xy[-nrow(xy), "L1"]
  e <- data.frame(from = id[-nrow(xy)][sl], to = id[-1][sl], line = xy[-1, "L1"][sl])
  e$len <- sqrt(rowSums((nxy[e$from, ] - nxy[e$to, ])^2)); e <- e[e$from != e$to, ]
  gu <- graph_from_data_frame(e[, 1:2], directed = FALSE, vertices = data.frame(name = seq_len(nrow(nxy))))
  comp <- components(gu); big <- which.max(comp$csize); lcc <- which(comp$membership == big)
  all_sf <- st_sf(id = seq_len(nrow(nxy)), geometry = st_sfc(lapply(seq_len(nrow(nxy)), function(i) st_point(nxy[i, ])), crs = 3035))
  lcc_sf <- all_sf[lcc, ]
  acc <- st_is_within_distance(green, lcc_sf, dist = 20)
  for (j in which(lengths(acc) == 0)) acc[[j]] <- st_nearest_feature(green[j, ], lcc_sf)
  nv <- nrow(nxy); virt <- nv + seq_len(nrow(green))
  ed <- rbind(data.frame(from = e$from, to = e$to, w = e$len / WALK_M_PER_MIN, line = e$line),
              data.frame(from = e$to, to = e$from, w = e$len / WALK_M_PER_MIN, line = e$line),
              do.call(rbind, lapply(seq_len(nrow(green)), function(j)
                data.frame(from = virt[j], to = lcc_sf$id[acc[[j]]], w = 0, line = NA_integer_))))
  gd <- graph_from_data_frame(ed, directed = TRUE, vertices = data.frame(name = seq_len(nv + nrow(green))))
  list(w = w, nxy = nxy, comp = comp, big = big, all_sf = all_sf, lcc_sf = lcc_sf, gd = gd, ed = ed, virt = virt)
}
route <- function(G, p) {
  node <- G$lcc_sf$id[st_nearest_feature(orig[p, ], G$lcc_sf)]
  tm <- as.numeric(distances(G$gd, v = node, to = G$virt, mode = "in", weights = G$ed$w))
  tm[tt$in_green[p, ]] <- 0
  j <- which.min(tm)
  sp <- shortest_paths(G$gd, from = node, to = G$virt[j], mode = "in", weights = G$ed$w, output = "both")
  vs <- as.integer(names(sp$vpath[[1]])); vs <- vs[vs <= nrow(G$nxy)]
  lines_used <- unique(G$ed$line[as.integer(sp$epath[[1]])]); lines_used <- lines_used[!is.na(lines_used)]
  geom <- if (length(vs) >= 2) st_linestring(G$nxy[vs, ]) else st_linestring(rbind(G$nxy[node, ], G$nxy[node, ]))
  list(t = tm[j], j = j, geom = geom, lines = lines_used)
}

Gf <- build(hw[hw$kept, ])                      # our filter
Ga <- build(hw[!is.na(hw$highway), ])           # unfiltered download (every highway way)
cat("filtered graph: nodes", nrow(Gf$nxy), "| unfiltered:", nrow(Ga$nxy), "\n")

# ---- Per point diagnostics ------------------------------------------------------------------------
near_way <- st_nearest_feature(orig[gap, ], hw)
res <- lapply(seq_along(gap), function(k) {
  p <- gap[k]
  rf <- route(Gf, p); ra <- route(Ga, p)
  # (c): nearest node of the filtered network (any component) and whether it is in the largest one
  an <- st_nearest_feature(orig[p, ], Gf$all_sf)
  an_comp <- Gf$comp$membership[an]
  # tags of ways the unfiltered route uses that our filter drops
  used <- Ga$w[ra$lines, ]
  dropped <- used[!used$kept, ]
  drop_tags <- if (nrow(dropped) == 0) "" else
    dropped %>% st_drop_geometry() %>%
      mutate(tag = paste0("highway=", highway, ifelse(is.na(foot), "", paste0(" foot=", foot)),
                          ifelse(is.na(access), "", paste0(" access=", access)),
                          ifelse(is.na(service), "", paste0(" service=", service)))) %>%
      distinct(osm_id, tag) %>% count(tag) %>% mutate(s = paste0(tag, " (", n, ")")) %>% pull(s) %>% paste(collapse = "; ")
  w <- hw[near_way[k], ]
  j <- own_j[p]
  tibble(network_point_id = orig$network_point_id[p], own_min = own[p], osrm_min = orig$atg[p], diff_min = d[p],
         own_patch = green$green_id[j], own_patch_class = green$ua_code[j], own_patch_ha = green$green_ha[j],
         straight_line_to_nearest_patch_m = min(as.numeric(st_distance(orig[p, ], green))),
         unfiltered_min = ra$t, unfiltered_patch = green$green_id[ra$j],
         snap_to_lcc_m = as.numeric(st_distance(orig[p, ], Gf$lcc_sf[st_nearest_feature(orig[p, ], Gf$lcc_sf), ])),
         nearest_node_component_size = Gf$comp$csize[an_comp], nearest_node_in_lcc = an_comp == Gf$big,
         dist_to_nearest_way_m = as.numeric(st_distance(orig[p, ], w)),
         nearest_way = paste0("osm ", w$osm_id, " highway=", w$highway,
                              ifelse(is.na(w$foot), "", paste0(" foot=", w$foot)),
                              ifelse(is.na(w$access), "", paste0(" access=", w$access))),
         nearest_way_kept = w$kept, unfiltered_route_dropped_ways = drop_tags,
         atg_snap_mode = orig$snap_mode[p], atg_snap_m = orig$snap_distance_m[p],
         geom_own = list(rf$geom), geom_unf = list(ra$geom))
}) %>% bind_rows()

res <- res %>% mutate(cause = case_when(
  !nearest_node_in_lcc & snap_to_lcc_m > 20 ~ "c",
  unfiltered_min <= osrm_min + 1 & nzchar(unfiltered_route_dropped_ways) ~ "a",
  dist_to_nearest_way_m > 5 ~ "b",
  unfiltered_min >= osrm_min + GAP_MIN ~ "b or d",
  TRUE ~ "d"))

# ---- Cells containing the points ------------------------------------------------------------------
cells <- read.csv(file.path(DOWN, "e2sfca_own_routing_cells.csv")) %>% mutate(gid = as.character(gid))
pc <- st_join(orig[gap, ] %>% select(network_point_id), fm %>% transmute(ID = as.character(unit_id)), join = st_within)
res <- res %>% left_join(st_drop_geometry(pc), by = "network_point_id")
mc <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")) %>% st_drop_geometry() %>%
  mutate(ID = as.character(ID))
q5 <- function(x) { q <- rep(NA_integer_, length(x)); ok <- !is.na(x); q[ok] <- dplyr::ntile(x[ok], 5); q }
mc <- mc %>% mutate(q_main = q5(priority_citizen), q_atg_walk = q5(priority_atg_walk))
cell_tab <- res %>% distinct(ID) %>%
  left_join(cells %>% transmute(ID = gid, assignment_status, own_atgclasses_zero_min = own_nearest_min_atgclasses_zero,
                                osrm_cell_min = nearest_green_sec / 60, own_mcda_min = own_nearest_min), by = "ID") %>%
  left_join(mc %>% select(ID, norm_green_time, norm_green_time_atg, priority_citizen, priority_atg_walk, q_main, q_atg_walk), by = "ID") %>%
  left_join(res %>% count(ID, name = "gap_points_in_cell"), by = "ID") %>%
  mutate(cell_diff_min = own_atgclasses_zero_min - osrm_cell_min)

# ---- Save tables ----------------------------------------------------------------------------------
pt_out <- res %>% select(-geom_own, -geom_unf) %>% mutate(across(where(is.double), ~ round(., 2)))
readr::write_csv(pt_out, file.path(OUT, "gap_points.csv"))
readr::write_csv(cell_tab %>% mutate(across(where(is.double), ~ round(., 3))), file.path(OUT, "gap_cells.csv"))
options(width = 250)
print(as.data.frame(pt_out %>% select(network_point_id, own_min, osrm_min, diff_min, own_patch, own_patch_class,
                                       unfiltered_min, snap_to_lcc_m, nearest_node_in_lcc, dist_to_nearest_way_m,
                                       nearest_way_kept, cause, ID)))
cat("\nNearest ways and dropped tags:\n")
print(as.data.frame(pt_out %>% select(network_point_id, nearest_way, unfiltered_route_dropped_ways)))
cat("\nCauses:\n"); print(table(res$cause))
cat("\nCells:", nrow(cell_tab), "\n"); print(as.data.frame(cell_tab %>% mutate(across(where(is.double), ~ round(., 2)))))

# ---- Maps of typical cases ------------------------------------------------------------------------
pick <- res %>% group_by(cause) %>% arrange(desc(diff_min)) %>% slice_head(n = 2) %>% ungroup() %>% slice_head(n = 6)
plots <- lapply(seq_len(nrow(pick)), function(k) {
  r <- pick[k, ]; p <- which(orig$network_point_id == r$network_point_id)
  lo <- st_sfc(r$geom_own[[1]], crs = 3035); lu <- st_sfc(r$geom_unf[[1]], crs = 3035)
  bb <- st_bbox(st_buffer(st_union(c(st_geometry(orig[p, ]), lo, lu)), 150))
  win <- st_as_sfc(bb)
  hw_w <- suppressWarnings(st_intersection(st_transform(hw, 3035), win))
  gr_w <- suppressWarnings(st_intersection(green, win))
  routes <- rbind(st_sf(route = "Our filter", geometry = lo), st_sf(route = "Unfiltered download", geometry = lu))
  ggplot() +
    geom_sf(data = gr_w, fill = "#b8dfae", colour = NA) +
    geom_sf(data = hw_w %>% filter(kept), colour = "grey70", linewidth = 0.3) +
    geom_sf(data = hw_w %>% filter(!kept), colour = "#d6604d", linewidth = 0.4, linetype = "22") +
    geom_sf(data = routes, aes(colour = route, linewidth = route)) +
    geom_sf(data = orig[p, ], shape = 21, fill = "black", colour = "white", size = 2.5) +
    scale_colour_manual(values = c("Our filter" = "#2166ac", "Unfiltered download" = "#b2182b"), name = NULL) +
    scale_linewidth_manual(values = c("Our filter" = 1.1, "Unfiltered download" = 0.6), guide = "none") +
    coord_sf(xlim = bb[c(1, 3)], ylim = bb[c(2, 4)], expand = FALSE, datum = NA) +
    labs(title = sprintf("Point %s, cause (%s)", r$network_point_id, r$cause),
         subtitle = sprintf("ours %.1f min, OSRM %.1f, unfiltered %.1f", r$own_min, r$osrm_min, r$unfiltered_min)) +
    theme_void(base_size = 9) + theme(legend.position = "bottom", plot.background = element_rect(fill = "white", colour = NA))
})
png(file.path(OUT, "gap_point_routes.png"), width = 3000, height = 1100 * ceiling(length(plots) / 3), res = 200, bg = "white")
gridExtra::grid.arrange(grobs = plots, ncol = 3)
dev.off()
cat("\nSaved to", OUT, "\n(grey = kept by our filter, dashed red = dropped by our filter, green = patches)\n")
