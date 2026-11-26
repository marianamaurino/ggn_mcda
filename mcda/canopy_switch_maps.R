# Malta priority quintiles before and after the street greenery switch (2026-11-23, spec 3.6), side by side.
# A = old score (Street Tree Layer 2018, data/malta/malta_mcda_processed_realloc_pre_canopy.rds),
# B = new score (street canopy, main file). Quintiles over the scored cells of each score.
# Drawing as spec 8.2: grid as a raster, outline 0.3 pt dark grey, local councils 0.15 pt light grey,
# outside white, one scale bar, no north arrow, no titles. Colours as Figures_MCDA.Rmd.
# Output: output/figures_mcda/canopy_switch_2026_11_23/priority_quintiles_old_new_canopy.*
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 \
#      nice -n 10 Rscript mcda/canopy_switch_maps.R

suppressPackageStartupMessages({ library(sf); library(dplyr); library(ggplot2); library(patchwork) })
source(here::here("R", "theme_lancet.R"))
OUT <- here::here("output/figures_mcda/canopy_switch_2026_11_23")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
lw_pt <- function(pt) pt / (ggplot2::.pt * 0.75)

old <- readRDS(here::here("data/malta/malta_mcda_processed_realloc_pre_canopy.rds"))
new <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds"))
stopifnot(identical(as.character(old$gid), as.character(new$gid)))
border <- st_sf(geometry = readRDS(here::here("data/malta/malta_union_boundary.rds")), crs = 3035)
councils <- st_read(here::here("data/malta/Population_Malta_Districts.geojson"), quiet = TRUE) %>%
  st_transform(3035) %>% group_by(NAME) %>% summarise(.groups = "drop") %>% st_intersection(st_union(border))

quint_colours <- c("Q1 (lowest)" = "#1a9641", "Q2" = "#a6d96a", "Q3" = "#ffffbf", "Q4" = "#fdae61",
                   "Q5 (highest)" = "#d73027", "No score" = "grey88")
xy <- st_coordinates(st_centroid(st_geometry(new)))
ox <- median(xy[, 1] %% 100); oy <- median(xy[, 2] %% 100)
cells <- tibble(x = round((xy[, 1] - ox) / 100) * 100 + ox, y = round((xy[, 2] - oy) / 100) * 100 + oy)
quint <- function(p) {
  q <- rep(NA_integer_, length(p)); q[!is.na(p)] <- ntile(p[!is.na(p)], 5)
  factor(ifelse(is.na(q), "No score", names(quint_colours)[q]), levels = names(quint_colours))
}
df <- bind_rows(cells %>% mutate(score = "A  Street Tree Layer 2018 (previous)", q = quint(old$priority_citizen)),
                cells %>% mutate(score = "B  Street canopy (current)", q = quint(new$priority_citizen)))
print(table(df$score, df$q))

bb <- st_bbox(border)
mask <- st_sf(geometry = st_difference(st_as_sfc(st_bbox(st_buffer(st_union(border), 2000))), st_union(border)))
panel <- function(d, bar) {
  ggplot() +
    geom_raster(data = d, aes(x, y, fill = q), interpolate = FALSE) +
    geom_sf(data = mask, fill = "white", colour = NA) +
    geom_sf(data = councils, fill = NA, colour = "grey75", linewidth = lw_pt(0.15)) +
    geom_sf(data = border, fill = NA, colour = "grey25", linewidth = lw_pt(0.3)) +
    scale_fill_manual(values = quint_colours, name = "Priority quintile", drop = FALSE) +
    (if (bar) lancet_scale_bar("bl") else NULL) +
    coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], crs = 3035, datum = NA, expand = TRUE) +
    labs(tag = unique(d$score), x = NULL, y = NULL) +
    theme_lancet_map(base_size = 8) +
    theme(plot.tag = element_text(size = 8, face = "bold", hjust = 0), plot.tag.position = c(0, 1),
          plot.margin = margin(12, 2, 2, 2))
}
p <- panel(filter(df, score == unique(df$score)[1]), TRUE) + panel(filter(df, score == unique(df$score)[2]), FALSE) +
  plot_layout(guides = "collect") & theme(legend.position = "bottom")
f <- save_figure_lancet(p, "priority_quintiles_old_new_canopy", OUT, height_mm = 110, width_mm = 180)
cat("Saved:", paste(f, collapse = "\n"), "\n")
