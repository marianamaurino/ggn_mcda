# Per criterion maps for the MCDA paper (instruction mcda/mcda_criteria_maps_2026_11_17.md and the
# decisions of 2026-11-19; rules in mcda/MCDA_paper_results_spec.md sections 1, 3 and 8).
#
# Each panel maps the raw layer the score's normalisation reads (Malta_MCDA_260702_realloc.Rmd and
# Klagenfurt_MCDA_260520.Rmd, chunk `normalization`), with the score's caps (p98 of the current
# data). Klagenfurt air quality is the composite the score reads: mean of normalised NO2 (log) and
# PM2.5, which carry half of the air quality weight each.
#
# Inputs: the saved score files for the Malta layers; for Klagenfurt the deduplicated master grid
# (one row per cell, mcda/klagenfurt_dedup_inputs.R) plus the joins the MCDA notebook makes
# (walking time, NO2/PM2.5 2021 gap filled, income), taken from the saved score file one row per
# cell, so no layer is recomputed here except the composite.
#
# Drawing: cells as a raster (no seams); outside the study area masked white; outline 0.3 pt dark
# grey; Malta local councils 0.15 pt light grey; no internal boundaries in Klagenfurt; one scale
# bar per figure (panel A); font from R/theme_lancet.R (as the HIA paper figures).
#
# Outputs (output/figures_mcda/criterion_maps_paper/):
#   Figure_criteria_Malta.*, Figure_criteria_Klagenfurt.*, FigureS_Klagenfurt_NO2_PM25.*
#   (PDF, SVG, PNG 300 dpi, editable PPTX); panels/*.png, one per panel, for checking.
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 \
#      nice -n 10 Rscript mcda/criteria_maps_paper.R

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(ggplot2); library(patchwork)
})
source(here::here("R", "theme_lancet.R"))
cat("Font:", lancet_font, "\n")

OUT_DIR   <- here::here("output/figures_mcda/criterion_maps_paper")
PANEL_DIR <- file.path(OUT_DIR, "panels")
dir.create(PANEL_DIR, showWarnings = FALSE, recursive = TRUE)
FIG_W <- 180  # mm, spec 8.1

lw_pt <- function(pt) pt / (ggplot2::.pt * 0.75)   # ggplot linewidth for a width in pt
p98 <- function(x) unname(quantile(x, 0.98, na.rm = TRUE))
p02 <- function(x) unname(quantile(x, 0.02, na.rm = TRUE))
minmax <- function(x, lo, hi) (pmax(pmin(x, hi), lo) - lo) / (hi - lo)

# ---- Data ---------------------------------------------------------------------------------
malta <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds")) %>%
  mutate(gid = as.character(gid)) %>%
  left_join(st_read(here::here("data/malta/Population_Malta_reallocated_nso.gpkg"), quiet = TRUE) %>%
              st_drop_geometry() %>%
              transmute(gid = as.character(gid), pop_nso = pop_reallocated_nso),
            by = "gid")
malta_border <- st_sf(geometry = readRDS(here::here("data/malta/malta_union_boundary.rds")), crs = 3035)
malta_councils <- st_read(here::here("data/malta/Population_Malta_Districts.geojson"), quiet = TRUE) %>%
  group_by(NAME) %>% summarise(.groups = "drop") %>%
  st_intersection(st_union(malta_border))

klag_master <- readRDS(here::here("data/klagenfurt/klagenfurt_master_full.rds"))
klag_joins  <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")) %>%
  st_drop_geometry() %>%
  distinct(ID, .keep_all = TRUE) %>%
  select(ID, nearest_green_min, no2_final, pm25_final, income_weighted)
klag <- klag_master %>%
  select(ID, popdense_2020, lst, dist_bs, new_trafficvol) %>%
  left_join(klag_joins, by = "ID") %>%
  mutate(
    # composite as the score reads it (Klagenfurt_MCDA_260520.Rmd, normalization)
    air_composite = (minmax(log1p(no2_final), log1p(min(no2_final, na.rm = TRUE)), log1p(p98(no2_final))) +
                     minmax(pm25_final, min(pm25_final, na.rm = TRUE), p98(pm25_final))) / 2)
klag_border <- readRDS(here::here("data/klagenfurt/klagenfurt_boundary.rds")) %>% st_transform(3035)

# ---- Checks (spec 1.1) --------------------------------------------------------------------
cat("Malta cells", nrow(malta), "distinct", n_distinct(malta$gid), "\n")
cat("Klagenfurt cells", nrow(klag), "distinct", n_distinct(klag$ID), "\n")
stopifnot(nrow(malta) == 10657, n_distinct(malta$gid) == 10657,
          nrow(klag) == 12418, n_distinct(klag$ID) == 12418, !anyNA(malta$pop_nso))

# ---- Shared scale limits (spec 8.3: criteria in both cities; LST excepted, own scale per city) --
both <- function(a, b, lo = NULL) c(if (is.null(lo)) min(a, b, na.rm = TRUE) else lo, max(p98(a), p98(b)))
LIM <- list(
  no2        = both(malta$no2_avg_21, klag$no2_final),
  dist_bs    = both(malta$dist_bs, klag$dist_bs, lo = 0),
  traffic    = both(malta$new_trafficvol, klag$new_trafficvol, lo = 0),
  green_time = both(malta$nearest_green_min, klag$nearest_green_min, lo = 0)
)

# ---- Raster drawing -----------------------------------------------------------------------
# cell centres snapped to the 100 m lattice (Klagenfurt centres jitter by < 1 m)
to_raster_df <- function(grid, var) {
  xy <- st_coordinates(st_centroid(st_geometry(grid)))
  ox <- median(xy[, 1] %% 100); oy <- median(xy[, 2] %% 100)
  tibble(x = round((xy[, 1] - ox) / 100) * 100 + ox,
         y = round((xy[, 2] - oy) / 100) * 100 + oy,
         value = grid[[var]])
}
# white mask outside the study area
outside_mask <- function(border, pad = 2000) {
  bb <- st_as_sfc(st_bbox(st_buffer(st_union(border), pad)))
  st_sf(geometry = st_difference(bb, st_union(border)))
}

map_panel <- function(df, border, internal, fill_scale, tag, bar, guide = "colourbar", extra = NULL,
                      bar_loc = "bl") {
  bb <- st_bbox(border)
  ggplot() +
    geom_raster(data = df, aes(x, y, fill = value), interpolate = FALSE) +
    extra +
    geom_sf(data = outside_mask(border), fill = "white", colour = NA) +
    (if (!is.null(internal)) geom_sf(data = internal, fill = NA, colour = "grey75",
                                     linewidth = lw_pt(0.15)) else NULL) +
    geom_sf(data = border, fill = NA, colour = "grey25", linewidth = lw_pt(0.3)) +
    fill_scale +
    (if (bar) lancet_scale_bar(bar_loc) else NULL) +
    coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], crs = 3035,
             datum = NA, expand = TRUE) +
    guides(fill = guide_colourbar(title.position = "top", barwidth = unit(30, "mm"),
                                  barheight = unit(2, "mm"))) +
    labs(tag = tag, x = NULL, y = NULL) +
    theme_lancet_map(base_size = 8) +
    theme(legend.position = "bottom", legend.title.position = "top",
          legend.title = element_text(size = 7), legend.text = element_text(size = 6),
          plot.tag = element_text(size = 8, face = "bold"), plot.tag.position = c(0, 1),
          legend.box.spacing = unit(1, "mm"), legend.margin = margin(0, 0, 0, 0),
          plot.margin = margin(9, 2, 4, 2))
}

grad <- function(colours, limits, title, accuracy = 1, trans = "identity", breaks = waiver(),
                 na = "grey88", labels = scales::label_comma(accuracy = accuracy)) {
  scale_fill_gradientn(colours = colours, limits = limits, oob = scales::squish, na.value = na,
                       name = title, trans = trans, breaks = breaks, labels = labels)
}

# ---- Palettes and titles shared by both cities --------------------------------------------
PAL <- list(
  pop     = c("#C6DBEF", "#6BAED6", "#2171B5", "#084594"),   # darker light tone than #EFF3FF
  lst     = viridisLite::magma(256),
  no2     = c("white", "#FEB24C", "#F03B20", "#BD0026"),
  pm25    = viridisLite::viridis(256, begin = 0.4),
  traffic = c("#EFEDF5", "#BCBDDC", "#807DBA", "#54278F", "#3F007D"),
  green_t = c("#1A6B1A", "#7BC96F", "#C6E48B", "#F4A261", "#E63946", "#6A1B4D"),
  blue    = c("dodgerblue3", "lightblue", "wheat", "sienna3"),
  tree    = c("#E5EEE7", "#A1C3A9", "#4E8A5E", "#0B4F2A"),
  imd     = c("#eef2f3", "#64798f"),
  green_pp = c("#8C510A", "#D8B365", "#F6E8C3", "#5AB4AC", "#01665E"),
  noise   = c("#FFEDA0", "#FEB24C", "#FD8D3C", "#E31A1C", "#800026"),
  rec     = c("#FEE6CE", "#FDAE6B", "#F16913", "#A63603"),
  income  = viridisLite::cividis(256)
)
sc <- list(
  no2     = grad(PAL$no2, LIM$no2, expression(NO[2] ~ "(µg/m³)")),
  traffic = grad(PAL$traffic, LIM$traffic, "Traffic volume (vehicles, log scale)", trans = "log1p",
                 breaks = c(0, 10, 100, 1000)),
  green_t = grad(PAL$green_t, LIM$green_time, "Walking time to green space (min)"),
  blue    = grad(PAL$blue, LIM$dist_bs, "Distance to blue space (m)")
)
# LST: own scale per city (decided 2026-11-19), min to p98 as the score
lst_scale <- function(x) grad(PAL$lst, c(min(x, na.rm = TRUE), p98(x)), "Land surface temperature (°C)")
pop_scale <- function(x) {
  cap <- p98(x[x > 0])
  list(scale = grad(PAL$pop, c(0, cap), "Residents per hectare", na = "#F0F0F0"), cap = cap)
}

# ---- Panel specs (order: spec 3.1 and 3.2, population first) ------------------------------
mp <- pop_scale(malta$pop_nso)
rec_cap <- p98(malta$walk_dist_m)
# Green per person as the score reads it (Malta_MCDA_260702_realloc.Rmd, norm_gpp_log, 2026-11-19):
# log10 scale, bounds p2 and p98 of the log over eligible populated cells, zero = lowest value
# (drawn at the lower bound), unpopulated cells missing (grey, like unrouted cells)
gpp_ref <- with(malta, green_m2_e2sfca_per_person_gauss[pop_nso > 0 & !ua_not_eligible &
                                                          green_m2_e2sfca_per_person_gauss > 0])
gpp_lim <- 10^unname(quantile(log10(gpp_ref), c(0.02, 0.98), na.rm = TRUE))
malta <- malta %>%
  mutate(gpp_map = if_else(pop_nso > 0, pmax(green_m2_e2sfca_per_person_gauss, gpp_lim[1]), NA_real_))
stopifnot(identical(is.na(malta$gpp_map), is.na(malta$norm_green_exp)))   # same cells as the score
malta_specs <- list(
  population = list("Population", "pop_nso", mp$scale, prep = function(v) if_else(v > 0, v, NA_real_)),
  lst        = list("Urban heat", "lst", lst_scale(malta$lst)),
  no2        = list("Air quality", "no2_avg_21", sc$no2),
  traffic    = list("Traffic", "new_trafficvol", sc$traffic),
  green_time = list("Green proximity", "nearest_green_min", sc$green_t),
  dist_bs    = list("Blue space", "dist_bs", sc$blue),
  tree       = list("Street greenery", "perc_tree",
                    grad(PAL$tree, c(0, p98(malta$perc_tree)), "Street tree cover (%)")),
  imd        = list("Grey infrastructure", "imd", grad(PAL$imd, c(0, 100), "Imperviousness (%)")),
  green_pp   = list("Green per person", "gpp_map",
                    grad(PAL$green_pp, gpp_lim, "Green space per person (m², E2SFCA, log scale)",
                         trans = "log10", breaks = c(0.1, 1, 10),
                         labels = scales::label_number(drop0trailing = TRUE))),
  noise      = list("Noise", "Lden", grad(PAL$noise, c(min(malta$Lden, na.rm = TRUE), p98(malta$Lden)),
                                          expression("Noise," ~ L[den] ~ "(dB)"))),
  recreation = list("Recreation", "walk_dist_m",
                    grad(PAL$rec, c(0, rec_cap), "Walking distance to recreation (m)",
                         breaks = c(0, 300, 1000, floor(rec_cap / 100) * 100)),
                    extra = function(df) geom_raster(data = filter(df, value == 0), aes(x, y),
                                                     fill = "#1B7837", interpolate = FALSE))
)

kp <- pop_scale(klag$popdense_2020)
klag_specs <- list(
  population = list("Population", "popdense_2020", kp$scale, prep = function(v) if_else(v > 0, v, NA_real_)),
  lst        = list("Urban heat", "lst", lst_scale(klag$lst)),
  air        = list("Air quality", "air_composite",
                    grad(PAL$no2, c(0, 1), "Air quality index (0 to 1)",
                         accuracy = 0.1)),
  traffic    = list("Traffic", "new_trafficvol", sc$traffic),
  green_time = list("Green proximity", "nearest_green_min", sc$green_t),
  dist_bs    = list("Blue space", "dist_bs", sc$blue),
  income     = list("Low income areas", "income_weighted",
                    grad(PAL$income, c(p02(klag$income_weighted), p98(klag$income_weighted)),
                         "Income, spatially weighted (€)"))
)
klag_supp <- list(
  no2  = list("NO2", "no2_final", sc$no2),
  pm25 = list("PM2.5", "pm25_final",
              grad(PAL$pm25, c(min(klag$pm25_final, na.rm = TRUE), p98(klag$pm25_final)),
                   expression(PM[2.5] ~ "(µg/m³)"), accuracy = 0.1))
)

# ---- Draw ---------------------------------------------------------------------------------
limits_report <- list()
draw_city <- function(city, grid, border, internal, specs, fig_name, height_mm, ncol, tag_labels = NULL,
                      bar_loc = "bl") {
  panels <- list()
  for (i in seq_along(specs)) {
    id <- names(specs)[i]; s <- specs[[i]]
    label <- if (is.null(tag_labels)) s[[1]] else tag_labels[i]
    tag <- paste0(LETTERS[i], "  ", label)
    cat("\n#", city, tag, "(", s[[2]], ")\n"); print(summary(grid[[s[[2]]]]))   # sanity check
    df <- to_raster_df(grid, s[[2]])
    if (!is.null(s$prep)) df$value <- s$prep(df$value)
    extra <- if (!is.null(s$extra)) s$extra(df) else NULL
    lim <- s[[3]]$get_limits()
    limits_report[[paste(city, id)]] <<- switch(s[[3]]$trans$name,
      log1p    = paste(round(expm1(lim), 1), collapse = " to "),
      `log-10` = paste(signif(10^lim, 3), collapse = " to "),
      paste(signif(lim, 4), collapse = " to "))
    p1 <- map_panel(df, border, internal, s[[3]], tag, bar = TRUE, extra = extra, bar_loc = bar_loc)
    ggsave(file.path(PANEL_DIR, sprintf("%s_%02d_%s.png", city, i, id)), p1, width = 80, height = 95,
           units = "mm", device = ragg::agg_png, res = 300, bg = "white")
    panels[[id]] <- map_panel(df, border, internal, s[[3]], tag, bar = i == 1, extra = extra,
                              bar_loc = bar_loc)
  }
  fig <- wrap_plots(panels, ncol = ncol)
  f <- c(save_figure_lancet(fig, fig_name, OUT_DIR, height_mm = height_mm, width_mm = FIG_W),
         save_figure_pptx(fig, fig_name, OUT_DIR, height_mm = height_mm, width_mm = FIG_W))
  cat("\nSaved:", paste(basename(f), collapse = ", "), "\n")
}

draw_city("Malta", malta, malta_border, malta_councils, malta_specs, "Figure_criteria_Malta", 170, 4)
draw_city("Klagenfurt", klag, klag_border, NULL, klag_specs, "Figure_criteria_Klagenfurt", 125, 4,
          bar_loc = "br")
draw_city("KlagenfurtS", klag, klag_border, NULL, klag_supp, "FigureS_Klagenfurt_NO2_PM25", 95, 2, bar_loc = "br",
          tag_labels = c("NO₂", "PM₂.₅"))

cat("\n== Scale limits ==\n")
for (id in names(limits_report)) cat(sprintf("%-24s %s\n", id, limits_report[[id]]))
cat("Population caps (p98 of populated cells): Malta", round(mp$cap, 1), "| Klagenfurt", round(kp$cap, 1), "\n")
