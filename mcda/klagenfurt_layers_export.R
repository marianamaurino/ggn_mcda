# Klagenfurt: one row per 100 m grid cell with the normalised criterion scores as they enter the WLC
# (available weight rule, >= 80% of weight, 2026-11-05), the citizen weighted priority score and its
# quintile, plus the criterion weights. For the UT2026 poster layer diagram.
#
# Air quality = mean of norm_no2 and norm_pm25: they carry equal weights in the WLC and are missing
# in the same cells, so the composite times their summed weight is exactly what enters the score
# (checked below). The saved grid repeats 101 cells (4 or 9 identical rows each); one row per cell
# here, and quintiles are computed on the unique cells.
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/klagenfurt_layers_export.R

suppressPackageStartupMessages({ library(dplyr); library(sf) })
OUT <- here::here("output/figures_mcda/poster")

k <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")) %>% st_transform(3035)
k <- k[!duplicated(k$ID), ]
stopifnot(nrow(k) == 12418, !anyDuplicated(k$ID))

nv <- c("norm_lst", "norm_dist_bs", "norm_no2", "norm_pm25", "norm_green_time", "norm_traffic_cat",
        "norm_income_weighted")
d <- st_drop_geometry(k)
fit <- lm(reformulate(nv, "priority_citizen", intercept = FALSE), data = d[rowSums(is.na(d[nv])) == 0, ])
w <- coef(fit)[nv]
stopifnot(max(abs(residuals(fit))) < 1e-9, abs(sum(w) - 1) < 1e-9, abs(w["norm_no2"] - w["norm_pm25"]) < 1e-12,
          identical(is.na(d$norm_no2), is.na(d$norm_pm25)))

crit <- tibble::tribble(
  ~layer_order, ~column,                ~criterion,                     ~from,
  1,            "s_urban_heat",         "Urban heat",                   "norm_lst",
  2,            "s_traffic",            "Traffic",                      "norm_traffic_cat",
  3,            "s_air_quality",        "Air quality (NO2 + PM2.5)",    "norm_no2+norm_pm25",
  4,            "s_blue_space_distance","Blue space distance",          "norm_dist_bs",
  5,            "s_low_income",         "Low income areas",             "norm_income_weighted",
  6,            "s_green_proximity",    "Green proximity (walking time)", "norm_green_time")
wt <- c(w["norm_lst"], w["norm_traffic_cat"], w["norm_no2"] + w["norm_pm25"], w["norm_dist_bs"],
        w["norm_income_weighted"], w["norm_green_time"])
crit$resident_weight_pct <- round(100 * unname(wt), 1)
crit$label <- sprintf("%s · %.1f%%", crit$criterion, crit$resident_weight_pct)

xy <- st_coordinates(st_centroid(st_geometry(k)))
out <- tibble(
  cell_id = d$ID,
  x_epsg3035 = round(xy[, 1], 1), y_epsg3035 = round(xy[, 2], 1),
  s_urban_heat = d$norm_lst, s_traffic = d$norm_traffic_cat,
  s_air_quality = (d$norm_no2 + d$norm_pm25) / 2,
  s_blue_space_distance = d$norm_dist_bs, s_low_income = d$norm_income_weighted,
  s_green_proximity = d$norm_green_time,
  weight_available = d$weight_available,
  priority_citizen = d$priority_citizen)
out$priority_quintile <- NA_integer_
ok <- !is.na(out$priority_citizen)
out$priority_quintile[ok] <- ntile(out$priority_citizen[ok], 5)

# Check: available weight mean of the 6 layers with their weights reproduces the saved score
S <- as.matrix(out[, crit$column]); A <- !is.na(S); S[!A] <- 0
rebuilt <- as.numeric(S %*% wt) / as.numeric(A %*% wt)
stopifnot(max(abs(rebuilt[ok] - out$priority_citizen[ok])) < 1e-12)

# Quintiles: unique cells vs all rows of the saved grid (as in the current priority map)
k_all <- st_drop_geometry(readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")))
q_all <- rep(NA_integer_, nrow(k_all)); oka <- !is.na(k_all$priority_citizen)
q_all[oka] <- ntile(k_all$priority_citizen[oka], 5)
q_map <- q_all[match(out$cell_id, k_all$ID)]
cat("Cells whose quintile differs from the current map (duplicates counted there):",
    sum(q_map != out$priority_quintile, na.rm = TRUE), "of", sum(ok), "\n")

readr::write_csv(out, file.path(OUT, "klagenfurt_mcda_cells_layers.csv"), na = "NA")
readr::write_csv(crit %>% select(layer_order, criterion, column, wlc_columns = from, resident_weight_pct, label),
                 file.path(OUT, "klagenfurt_mcda_layer_weights.csv"))
cat("Rows:", nrow(out), "| scored:", sum(ok), "| no score:", sum(!ok), "\n")
print(summary(out[, c(crit$column, "priority_citizen")]))
print(table(out$priority_quintile, useNA = "ifany"))
print(as.data.frame(crit %>% select(layer_order, criterion, resident_weight_pct)))
