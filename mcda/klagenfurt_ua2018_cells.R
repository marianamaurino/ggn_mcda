# Klagenfurt: Urban Atlas 2018 area per class and grid cell, for the water constraint (spec 1.3, 25 November 2026).
# The Urban Atlas 2021 land use layer of Klagenfurt is not on the server (ATGreen's extract was on another
# machine) and could not be downloaded on 25 November 2026, so Klagenfurt water cells come from Urban Atlas 2018.
#
# Source: ../ggn_analysis_archive/data_raw/urban_atlas_2018/Land_uses.zip, member
# Land_uses/UBD_urbanatlas_2018_0.feather (16 January 2025): m2 of each of the 27 Urban Atlas 2018 classes in each
# cell of a 100 m grid (column gid, total_area = 10,000 m2). Its gid is the gid of data/klagenfurt/kla_green_final.gpkg
# (11,996 cells, all found). Cells are linked to the MCDA grid by centroid (the two grids coincide within 0.2 m) and
# keyed by ID (spec 1.1: never join by gid). The 422 MCDA cells outside kla_green_final have no Urban Atlas 2018 row
# (none of them is scored).
#
# Output: data/klagenfurt/klagenfurt_ua2018_class_area_cells.csv (ID, one column per class code, total_area).
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 nice -n 10 Rscript mcda/klagenfurt_ua2018_cells.R

library(dplyr)
library(sf)
library(arrow)

zip_path <- here::here("data_raw/urban_atlas_2018/Land_uses.zip")
member   <- "Land_uses/UBD_urbanatlas_2018_0.feather"
tmp <- tempfile("ua2018_"); dir.create(tmp)
unzip(zip_path, files = member, exdir = tmp)
feather <- file.path(tmp, member)

grid_ubd <- st_read(here::here("data/klagenfurt/kla_green_final.gpkg"), quiet = TRUE) %>% select(gid)
kl <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")) %>% select(ID)
stopifnot(nrow(kl) == 12418, n_distinct(kl$ID) == 12418)

link <- suppressWarnings(st_join(st_centroid(kl), grid_ubd, join = st_within)) %>% st_drop_geometry()
stopifnot(!any(duplicated(link$ID)))
cat("MCDA cells linked to the Urban Atlas 2018 grid:", sum(!is.na(link$gid)), "of", nrow(link), "\n")

ids <- as.numeric(grid_ubd$gid)
tab <- open_dataset(feather, format = "feather") %>% filter(gid %in% ids) %>% collect()
stopifnot(nrow(tab) == length(ids), all(abs(tab$total_area - 1e4) < 1e-6))

out <- link %>% filter(!is.na(gid)) %>%
  mutate(gid = as.numeric(gid)) %>%
  left_join(tab %>% mutate(gid = as.numeric(gid)), by = "gid") %>%
  select(-gid)
stopifnot(nrow(out) == 11996, !anyNA(out))
readr::write_csv(out, here::here("data/klagenfurt/klagenfurt_ua2018_class_area_cells.csv"))
cat("Written:", nrow(out), "cells; water (50000) majority by class area:",
    sum(apply(as.matrix(out[, setdiff(names(out), c("ID", "total_area"))]), 1, which.max) ==
          which(setdiff(names(out), c("ID", "total_area")) == "50000")), "\n")
unlink(tmp, recursive = TRUE)
