# Effect of the traffic switch (OpenTransportMap classes -> OSM road type K3, spec 3.4, 2026-11-24) on both
# scores. Old = *_pre_roadtype.rds backups, new = the main score files. Instruction: mcda/Traffic_instructions.Rmd,
# section 4 (steps 3, 6 and 7). Outputs: output/figures_mcda/traffic_k3_switch_2026_11_24/ (tables as CSV,
# figures as PDF, SVG and PNG).
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 \
#      nice -n 10 Rscript mcda/traffic_k3_switch_effects.R

suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(sf); library(purrr); library(ggplot2); library(patchwork) })
source(here::here("R/theme_lancet.R"))
source(here::here("mcda/traffic_road_type_k3.R"))
sf_use_s2(FALSE)
OUT <- here::here("output/figures_mcda/traffic_k3_switch_2026_11_24")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
SEED <- 20261120; N_PERM <- 200
lw_pt <- function(pt) pt / (ggplot2::.pt * 0.75)
save_fig <- function(p, name, h, w = 180) invisible(save_figure_lancet(p, name, OUT, height_mm = h, width_mm = w))
show <- function(x, nm) {
  cat("\n==", nm, "\n"); print(as.data.frame(mutate(x, across(where(is.double), ~ round(., 3)))), row.names = FALSE)
  readr::write_csv(x, file.path(OUT, paste0(nm, ".csv")))
}

# ---- Data -------------------------------------------------------------------------------------
read_city <- function(cn) {
  if (cn == "Malta") {
    old <- readRDS(here::here("data/malta/malta_mcda_processed_realloc_pre_roadtype.rds"))
    new <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds"))
    stopifnot(nrow(old) == 10657, nrow(new) == 10657, identical(as.character(old$gid), as.character(new$gid)))
    unit <- new$NAME; pop <- new$Total_Population
  } else {
    old <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may_pre_roadtype.rds"))
    new <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds"))
    stopifnot(nrow(old) == 12418, nrow(new) == 12418, identical(old$ID, new$ID))
    zsp <- st_read(here::here("data/klagenfurt/klagenfurt_zsp_aest.gpkg"), quiet = TRUE) %>% st_transform(st_crs(new))
    unit <- as.character(zsp$g_id[sapply(st_intersects(st_centroid(st_geometry(new)), zsp), function(i) if (length(i)) i[1] else NA)])
    pop <- new$popdense_2020
    old$norm_air <- (old$norm_no2 + old$norm_pm25) / 2; new$norm_air <- (new$norm_no2 + new$norm_pm25) / 2
  }
  list(old = old, new = new, unit = unit, pop = pop)
}
D <- list(Malta = read_city("Malta"), Klagenfurt = read_city("Klagenfurt"))

crit <- list(Malta = c("norm_lst", "norm_imd", "norm_dist_bs", "norm_Lden", "norm_traffic", "norm_no2", "norm_tree",
                       "norm_green_time", "norm_dist_rec", "norm_green_exp"),
             Klagenfurt = c("norm_lst", "norm_dist_bs", "norm_no2", "norm_pm25", "norm_green_time", "norm_traffic_cat",
                            "norm_income_weighted"))
lab <- c(norm_lst = "Urban heat", norm_imd = "Grey infrastructure", norm_dist_bs = "Blue space", norm_Lden = "Noise",
         norm_traffic = "Traffic", norm_traffic_cat = "Traffic", norm_no2 = "NO2", norm_pm25 = "PM2.5",
         norm_air = "Air quality", norm_tree = "Street greenery", norm_green_time = "Green proximity",
         norm_dist_rec = "Recreation", norm_green_exp = "Green per person", norm_income_weighted = "Low income")
# Step 3 criteria (Klagenfurt air quality as one criterion, as in Burden_coincidence_random_weights.Rmd)
crit3 <- list(Malta = crit$Malta,
              Klagenfurt = c("norm_lst", "norm_dist_bs", "norm_air", "norm_green_time", "norm_traffic_cat", "norm_income_weighted"))

get_w <- function(d, v) {
  d <- st_drop_geometry(d); cc <- d[complete.cases(d[, v]) & !is.na(d$priority_citizen), ]
  f <- lm(reformulate(v, "priority_citizen", intercept = FALSE), data = cc)
  stopifnot(max(abs(residuals(f))) < 1e-8); coef(f)[v]
}
top_q <- function(p) { q <- rep(NA_integer_, length(p)); q[!is.na(p)] <- ntile(p[!is.na(p)], 5); q }
pair <- function(a, b, subset = rep(TRUE, length(a))) {
  qa <- top_q(a); qb <- top_q(b); k <- !is.na(a) & !is.na(b) & subset
  tibble(cells = sum(k), spearman = cor(a[k], b[k], method = "spearman"),
         top_quintile_overlap_pct = 100 * sum(qa == 5 & qb == 5 & k) / sum(qa == 5 & k),
         cells_changing_quintile_pct = 100 * mean(qa[k] != qb[k]))
}
W <- map(names(D), function(cn) {
  wo <- get_w(D[[cn]]$old, crit[[cn]]); wn <- get_w(D[[cn]]$new, crit[[cn]])
  stopifnot(max(abs(wo - wn)) < 1e-10); wn }) %>% setNames(names(D))

# ---- Step 3 report: tunnels -------------------------------------------------------------------
rt <- list(
  Malta = road_type_k3(D$Malta$new, "gid", here::here("data/malta/accessibility_malta/own_routing/osm_highways_raw.gpkg"),
                       here::here("data/malta/accessibility_malta/own_routing/osm_tunnel_covered_tags_2026-11-24.json"),
                       st_sf(geometry = readRDS(here::here("data/malta/malta_union_boundary.rds")), crs = 3035)),
  Klagenfurt = road_type_k3(D$Klagenfurt$new, "ID", here::here("data/klagenfurt/accessibility_klagenfurt/own_routing/osm_highways_raw.gpkg"),
                            here::here("data/klagenfurt/accessibility_klagenfurt/own_routing/osm_tunnel_covered_tags_2026-11-24.json"),
                            readRDS(here::here("data/klagenfurt/klagenfurt_boundary.rds"))))
for (cn in names(rt)) stopifnot(identical(rt[[cn]]$cells$K3, if (cn == "Malta") D$Malta$new$norm_traffic else D$Klagenfurt$new$norm_traffic_cat))
tun_class <- imap_dfr(rt, ~ st_drop_geometry(.x$tunnels) %>% group_by(city = .y, class) %>%
                        summarise(ways = n(), km = sum(km), .groups = "drop"))
show(tun_class, "tunnels_km_by_class")
tun_named <- imap_dfr(rt, ~ st_drop_geometry(.x$tunnels) %>% filter(!is.na(name)) %>%
                        group_by(city = .y, name, class, tunnel = coalesce(tunnel, ""), covered = coalesce(covered, "")) %>%
                        summarise(km = sum(km), .groups = "drop") %>% arrange(city, desc(km)))
show(tun_named, "tunnels_named")
tun_cells <- imap_dfr(rt, ~ .x$cells %>% count(city = .y, K3_with_tunnels, K3, name = "cells") %>% filter(K3_with_tunnels != K3))
show(tun_cells, "tunnel_rule_cells_changed")
areas <- list(Malta = st_sf(geometry = readRDS(here::here("data/malta/malta_union_boundary.rds")), crs = 3035),
              Klagenfurt = readRDS(here::here("data/klagenfurt/klagenfurt_boundary.rds")) %>% st_transform(3035) %>% st_union() %>% st_sf(geometry = .))
roads_main <- map(c(Malta = "data/malta/accessibility_malta/own_routing/osm_highways_raw.gpkg",
                    Klagenfurt = "data/klagenfurt/accessibility_klagenfurt/own_routing/osm_highways_raw.gpkg"),
                  ~ st_read(here::here(.x), quiet = TRUE) %>% st_transform(3035) %>%
                    filter(sub("_link$", "", highway) %in% c("motorway", "trunk", "primary", "secondary", "tertiary")))
tmap <- function(cn) {
  b <- areas[[cn]]; bb <- st_bbox(b)
  ggplot() + geom_sf(data = st_intersection(roads_main[[cn]], st_union(b)), colour = "grey70", linewidth = lw_pt(0.3)) +
    geom_sf(data = rt[[cn]]$tunnels, aes(colour = "Tunnel or covered (dropped)"), linewidth = lw_pt(1.2)) +
    geom_sf(data = b, fill = NA, colour = "grey25", linewidth = lw_pt(0.3)) +
    scale_colour_manual(values = c(`Tunnel or covered (dropped)` = "#d73027"), name = NULL) +
    lancet_scale_bar("bl") + coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], crs = 3035, datum = NA) +
    labs(tag = cn) + theme_lancet_map(base_size = 8) + theme(legend.position = "bottom", plot.tag = element_text(size = 8, face = "bold"))
}
save_fig(tmap("Malta") + tmap("Klagenfurt") + plot_layout(guides = "collect") & theme(legend.position = "bottom"),
         "tunnels_map", 100)

# ---- Step 6. Consistency check vs traffic_road_type.Rmd Step 3f (no tunnel rule) ---------------
expected <- tibble(city = c("Malta", "Klagenfurt"), exp_spearman = c(0.983, 0.978), exp_overlap = c(84.3, 85.3))
cons <- imap_dfr(D, ~ pair(.x$old$priority_citizen, .x$new$priority_citizen) %>% mutate(city = .y, .before = 1)) %>%
  left_join(expected, by = "city") %>%
  mutate(diff_spearman = spearman - exp_spearman, diff_overlap = top_quintile_overlap_pct - exp_overlap,
         ok = abs(diff_spearman) <= 0.01)
show(cons, "consistency_check")
if (!all(cons$ok)) stop("Consistency check failed: Spearman differs by more than 0.01, see consistency_check.csv")

# ---- Step 7. Old vs new -----------------------------------------------------------------------
for_both <- function(f) imap_dfr(D, function(x, cn) bind_rows(f(x$old, x, cn) %>% mutate(score = "Old (OpenTransportMap)", .before = 1),
                                                              f(x$new, x, cn) %>% mutate(score = "New (road type K3)", .before = 1)) %>%
                                   mutate(city = cn, .before = 1))
show(for_both(function(d, x, cn) tibble(scored_cells = sum(!is.na(d$priority_citizen)))), "scored_cells")

units_top <- for_both(function(d, x, cn) {
  q <- top_q(d$priority_citizen)
  tibble(unit = x$unit, q = q) %>% filter(!is.na(q), !is.na(unit)) %>% group_by(unit) %>%
    summarise(scored_cells = n(), top_quintile_cells = sum(q == 5), top_quintile_pct_of_unit = 100 * mean(q == 5), .groups = "drop") %>%
    filter(scored_cells >= 20) %>% arrange(desc(top_quintile_pct_of_unit)) %>% slice(1:5) %>% mutate(rank = 1:5, .before = 1)
})
show(units_top, "top5_units")
# Klagenfurt statistical districts are small and many reach 100%: also rank by number of top quintile cells,
# with the share of all top quintile cells of the city that lie in the unit
units_top_n <- for_both(function(d, x, cn) {
  q <- top_q(d$priority_citizen)
  tibble(unit = x$unit, q = q) %>% filter(!is.na(q), !is.na(unit)) %>% group_by(unit) %>%
    summarise(scored_cells = n(), top_quintile_cells = sum(q == 5), top_quintile_pct_of_unit = 100 * mean(q == 5), .groups = "drop") %>%
    mutate(pct_of_city_top_quintile = 100 * top_quintile_cells / sum(top_quintile_cells)) %>%
    arrange(desc(top_quintile_cells)) %>% slice(1:5) %>% mutate(rank = 1:5, .before = 1)
})
show(units_top_n, "top5_units_by_count")

pop_top <- for_both(function(d, x, cn) {
  q <- top_q(d$priority_citizen); s <- !is.na(d$priority_citizen)
  tibble(population_top_quintile = sum(x$pop[q %in% 5], na.rm = TRUE),
         population_top_quintile_pct = 100 * sum(x$pop[q %in% 5], na.rm = TRUE) / sum(x$pop[s], na.rm = TRUE))
})
show(pop_top, "population_top_quintile")

shares <- for_both(function(d, x, cn) {
  w <- W[[cn]]; top <- which(top_q(d$priority_citizen) == 5)
  c5 <- colMeans(st_drop_geometry(d)[top, names(w)], na.rm = TRUE) * w
  tibble(criterion = lab[names(w)], weight_pct = 100 * w, share_top_quintile_pct = 100 * c5 / sum(c5))
}) %>% pivot_wider(names_from = score, values_from = share_top_quintile_pct)
show(shares, "criterion_shares_top_quintile")

eq <- for_both(function(d, x, cn) pair(d$priority_citizen, d$priority_equal))
show(eq, "citizen_vs_equal")

sens <- bind_rows(
  readRDS(here::here("data/malta/malta_sensitivity_pre_roadtype.rds")) %>% mutate(city = "Malta", score = "Old"),
  readRDS(here::here("data/malta/malta_sensitivity.rds")) %>% mutate(city = "Malta", score = "New"),
  readRDS(here::here("data/klagenfurt/klag_sensitivity_pre_roadtype.rds")) %>% mutate(city = "Klagenfurt", score = "Old"),
  readRDS(here::here("data/klagenfurt/klag_sensitivity.rds")) %>% mutate(city = "Klagenfurt", score = "New")) %>%
  select(city, score, test_name, spearman_r, class_agreement) %>%
  pivot_wider(names_from = score, values_from = c(spearman_r, class_agreement))
show(sens, "sensitivity_old_new")

# Step 3 (burden coincidence): top class per criterion with the tie rule, observed vs shuffled
topclass <- function(S) apply(S, 2, function(x) {
  q <- quantile(x, 0.8, na.rm = TRUE); t <- !is.na(x) & x >= q
  if (mean(t[!is.na(x)]) > 0.25) t <- !is.na(x) & x > q
  t
})
step3 <- for_both(function(d, x, cn) {
  d <- st_drop_geometry(d); S <- as.matrix(d[d$scored, crit3[[cn]]]); tc <- topclass(S); obs <- rowSums(tc)
  set.seed(SEED); perm <- replicate(N_PERM, mean(rowSums(apply(tc, 2, sample)) >= 3))
  bind_cols(as_tibble(as.list(setNames(100 * colMeans(tc), paste0("top_class_pct_", lab[crit3[[cn]]])))),
            tibble(top_3plus_pct = 100 * mean(obs >= 3), top_3plus_pct_shuffled = 100 * mean(perm),
                   ratio_to_shuffled = mean(obs >= 3) / mean(perm)))
})
show(step3, "step3_burden_coincidence")
cat("\nKlagenfurt traffic top class share (was 8.1%):",
    round(step3$top_class_pct_Traffic[step3$city == "Klagenfurt"], 1), "\n")

# Spearman matrix of all criteria (new scores), redundancy check |rho| >= 0.70
cmat <- imap_dfr(D, function(x, cn) {
  v <- if (cn == "Malta") crit$Malta else c(crit$Klagenfurt, "norm_air")
  d <- st_drop_geometry(x$new)[x$new$scored, v]
  m <- cor(d, method = "spearman", use = "pairwise.complete.obs")
  as.data.frame(as.table(m)) %>% setNames(c("a", "b", "rho")) %>%
    mutate(city = cn, a = lab[as.character(a)], b = lab[as.character(b)])
})
show(cmat %>% filter(a < b) %>% mutate(above_0.70 = abs(rho) >= 0.70) %>% arrange(city, desc(abs(rho))), "criteria_spearman")
fm <- ggplot(cmat, aes(a, b, fill = rho)) + geom_tile() + geom_text(aes(label = sprintf("%.2f", rho)), size = 1.8) +
  facet_wrap(~ city, scales = "free") + scale_fill_distiller(palette = "RdBu", limits = c(-1, 1), name = "Spearman") +
  labs(x = NULL, y = NULL) + theme_lancet() + theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_fig(fm, "criteria_spearman", 100)

# Maps: priority quintiles old vs new, and cells changing quintile by 2 or more
quint_colours <- c("Q1 (lowest)" = "#1a9641", "Q2" = "#a6d96a", "Q3" = "#ffffbf", "Q4" = "#fdae61",
                   "Q5 (highest)" = "#d73027", "No score" = "grey88")
councils <- st_read(here::here("data/malta/Population_Malta_Districts.geojson"), quiet = TRUE) %>%
  st_transform(3035) %>% group_by(NAME) %>% summarise(.groups = "drop") %>% st_intersection(st_union(areas$Malta))
ras <- function(g) {
  xy <- st_coordinates(st_centroid(st_geometry(st_transform(g, 3035)))); ox <- median(xy[, 1] %% 100); oy <- median(xy[, 2] %% 100)
  tibble(x = round((xy[, 1] - ox) / 100) * 100 + ox, y = round((xy[, 2] - oy) / 100) * 100 + oy)
}
qf <- function(p) { q <- top_q(p); factor(ifelse(is.na(q), "No score", names(quint_colours)[q]), levels = names(quint_colours)) }
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
chg_tab <- list()
for (cn in names(D)) {
  d <- ras(D[[cn]]$new); po <- D[[cn]]$old$priority_citizen; pn <- D[[cn]]$new$priority_citizen
  qs <- scale_fill_manual(values = quint_colours, name = "Priority quintile", drop = FALSE)
  ch <- abs(top_q(po) - top_q(pn)) >= 2
  chf <- factor(ifelse(!is.na(ch) & ch, "Changed by 2 or more", "Changed by less than 2 or not scored"),
                levels = c("Changed by 2 or more", "Changed by less than 2 or not scored"))
  chg_tab[[cn]] <- tibble(city = cn, scored_cells = sum(!is.na(ch)), changed_2plus = sum(ch, na.rm = TRUE),
                          changed_2plus_pct = 100 * mean(ch, na.rm = TRUE))
  p <- (panel(cn, d, qf(po), qs, "A  Old traffic (OTM)", TRUE) +
          panel(cn, d, qf(pn), qs, "B  New traffic (K3)", FALSE) + plot_layout(guides = "collect")) /
       panel(cn, d, chf, scale_fill_manual(values = c("#7b3294", "grey90"), name = NULL, drop = FALSE), "C  Quintile change", FALSE) &
       theme(legend.position = "bottom")
  save_fig(p, paste0("priority_quintiles_old_new_", tolower(cn)), 200)
}
show(bind_rows(chg_tab), "cells_changing_2plus_quintiles")
cat("\nOutputs in", OUT, "\n")
