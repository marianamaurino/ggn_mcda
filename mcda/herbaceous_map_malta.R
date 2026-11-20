# Map: Urban Atlas 2021 class 32000 (herbaceous vegetation) in the Malta study area, on satellite imagery
# (Esri World Imagery; Google satellite tiles cannot be used outside Google's APIs).
# Patches as in mcda/green_class_32000_test.R: >= 500 m2, within 1,100 m of the study area (ATGreen's rule).
# Output: output/figures_mcda/green_class_32000_test/malta_herbaceous_satellite.png
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 nice -n 10 Rscript mcda/herbaceous_map_malta.R

suppressPackageStartupMessages({
  library(dplyr); library(sf); library(arrow); library(ggplot2); library(maptiles); library(tidyterra)
})
OUT <- here::here("output/figures_mcda/green_class_32000_test")

fm <- read_parquet(here::here("accessibility_schifanella/exposure/results/final_metrics.parquet")) %>% as.data.frame()
study <- st_union(st_as_sfc(structure(as.list(fm$geometry), class = "WKB"), crs = 3035))

herb <- st_read(here::here("data/urban_atlas/Malta_UA21/CLMS_UA_LCU_S2021_V025ha_MT001L1_VALLETTA_03035_V01_R00_20241025.fgb"),
                quiet = TRUE) %>%
  filter(code_2021 == "32000") %>%
  st_make_valid() %>%
  mutate(a = as.numeric(st_area(geometry))) %>%
  filter(a >= 500, as.numeric(st_distance(geometry, study)) <= 1100)
cat("32000 patches:", nrow(herb), "| ha:", round(sum(herb$a) / 1e4, 1), "\n")
stopifnot(nrow(herb) == 409)

# Web Mercator for the tiles; extent = study area + patches, small margin
herb_m  <- st_transform(herb, 3857)
study_m <- st_transform(study, 3857)
ext <- st_as_sfc(st_bbox(st_union(st_geometry(herb_m), study_m))) %>% st_buffer(300)
sat <- get_tiles(ext, provider = "Esri.WorldImagery", zoom = 14, crop = TRUE)

bb <- st_bbox(ext)
p <- ggplot() +
  geom_spatraster_rgb(data = sat, maxcell = terra::ncell(sat)) +   # full resolution, no resampling
  geom_sf(data = herb_m, fill = "#ffd400", colour = "#ffd400", alpha = 0.55, linewidth = 0.2) +
  geom_sf(data = study_m, fill = NA, colour = "white", linewidth = 0.4, linetype = "22") +
  coord_sf(xlim = bb[c(1, 3)], ylim = bb[c(2, 4)], expand = FALSE, datum = NA) +
  labs(title = "Herbaceous vegetation (Urban Atlas 2021, class 32000), Malta",
       subtitle = sprintf("%d patches >= 500 m2, %.0f ha; dashed line = study area", nrow(herb), sum(herb$a) / 1e4),
       caption = "Imagery: Esri, Maxar, Earthstar Geographics, and the GIS User Community. Land cover: Copernicus Urban Atlas 2021.") +
  theme_void(base_size = 9) +
  theme(plot.caption = element_text(size = 6, hjust = 0), plot.margin = margin(4, 4, 4, 4),
        plot.background = element_rect(fill = "white", colour = NA))
ggsave(file.path(OUT, "malta_herbaceous_satellite.png"), p, width = 200, height = 190, units = "mm", dpi = 300,
       bg = "white")
cat("Saved", file.path(OUT, "malta_herbaceous_satellite.png"), "\n")
