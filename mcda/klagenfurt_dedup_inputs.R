# Removes the duplicated Klagenfurt grid cells at their source (2026-11-19; spec 1.1).
#
# Origin of the duplicates:
#   1. sandbox/Plot_klagenfurt.Rmd (../ggn_analysis_archive, March 2026), the last writer of
#      data/klagenfurt/klagenfurt_master_full.rds, left joined klagenfurt_recreation_areas.csv by gid.
#      That CSV has one row per cell x category (nature, sports, active_living, blue_spaces, beaches),
#      so 101 cells with 2 or 3 categories were repeated (12,525 rows, 12,418 cells). Only
#      recreation_m2 differs between the copies.
#   2. data/klagenfurt/klagenfurt_grid_100m_income.geojson (built outside this repo, May 2026) was
#      made from that grid and carries the same 101 repeats (identical rows). Klagenfurt_MCDA_260520.Rmd
#      joins it by ID, so the repeats multiply: 2 x 2 = 4 and 3 x 3 = 9 rows (12,751 rows).
#
# Fix: one row per cell in both files. recreation_m2 is rebuilt as the sum over categories per cell,
# with "beaches" dropped because it repeats a "blue_spaces" row with the same area (the rule
# malta_build_master.Rmd uses for Malta). recreation_m2 is not a Klagenfurt MCDA criterion.
# The previous files are kept as *_pre_dedup.
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/klagenfurt_dedup_inputs.R

suppressPackageStartupMessages({ library(sf); library(dplyr) })

f_master <- here::here("data/klagenfurt/klagenfurt_master_full.rds")
f_income <- here::here("data/klagenfurt/klagenfurt_grid_100m_income.geojson")
f_rec    <- here::here("data/klagenfurt/klagenfurt_recreation_areas.csv")
N_CELLS  <- 12418

backup <- function(f) {
  b <- sub("(\\.[a-z]+)$", "_pre_dedup\\1", f)
  if (!file.exists(b)) file.copy(f, b) else message("Backup exists, kept: ", basename(b))
  cat("Backup:", b, "| md5", unname(tools::md5sum(b)), "\n")
}

# ---- master_full --------------------------------------------------------------------------
master <- readRDS(f_master)
if (nrow(master) == N_CELLS && n_distinct(master$ID) == N_CELLS) {
  cat("master_full already one row per cell, nothing to do\n")
} else {
  backup(f_master)
  # every column except recreation_m2 must be identical within a cell
  chk <- master %>% st_drop_geometry() %>% select(-recreation_m2) %>% distinct()
  stopifnot(nrow(chk) == N_CELLS)

  rec <- read.csv(f_rec) %>%
    filter(category != "beaches") %>%
    group_by(gid = as.character(gid)) %>%
    summarise(recreation_m2 = sum(intersect_area_m2), .groups = "drop")

  old_rec <- master %>% st_drop_geometry() %>% distinct(ID, gid, recreation_m2)
  master_new <- master %>%
    select(-recreation_m2) %>%
    distinct(ID, .keep_all = TRUE) %>%
    mutate(gid = as.character(gid)) %>%
    left_join(rec, by = "gid") %>%
    relocate(recreation_m2, .before = geometry)
  stopifnot(nrow(master_new) == N_CELLS, n_distinct(master_new$ID) == N_CELLS)

  # cells that were not duplicated keep their recreation value (beaches aside)
  single <- old_rec %>% group_by(ID) %>% filter(n() == 1) %>% ungroup()
  cmp <- single %>% inner_join(st_drop_geometry(master_new) %>% select(ID, rec_new = recreation_m2), by = "ID")
  cat("Non duplicated cells with a changed recreation_m2:",
      sum(xor(is.na(cmp$recreation_m2), is.na(cmp$rec_new)) |
            abs(cmp$recreation_m2 - cmp$rec_new) > 1e-6, na.rm = TRUE), "\n")
  cat("recreation_m2 > 10,000 m2 (overlapping categories summed):",
      sum(master_new$recreation_m2 > 10000, na.rm = TRUE), "cells\n")
  summary(master_new$recreation_m2)

  saveRDS(master_new, f_master)
  cat("Written:", f_master, nrow(master_new), "rows | md5", unname(tools::md5sum(f_master)), "\n")
}

# ---- income geojson -----------------------------------------------------------------------
income <- st_read(f_income, quiet = TRUE)
if (nrow(income) == N_CELLS) {
  cat("income geojson already one row per cell, nothing to do\n")
} else {
  backup(f_income)
  income_new <- income %>% distinct()
  stopifnot(nrow(income_new) == N_CELLS, n_distinct(income_new$ID) == N_CELLS)
  st_write(income_new, f_income, delete_dsn = TRUE, quiet = TRUE)
  cat("Written:", f_income, nrow(income_new), "rows | md5", unname(tools::md5sum(f_income)), "\n")
}
