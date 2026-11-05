# Malta MCDA: missing values per indicator and rescoring without dropping whole cells (2026-11-05).
#
# Reads the saved MCDA grid (data/malta/malta_mcda_processed_realloc.rds) and the new population grid;
# does not re-run or overwrite the MCDA. Writes tables, maps and an alternative priority map to
# output/figures_mcda/missing_values/.
#
# Scores compared
#   current      saved priority_citizen: a cell is scored only if all 10 criteria are present
#                (green per person NA was set to 0 in the MCDA, so it never drops a cell)
#   avail        Methods rule: sum(w_i s_i) / sum(w_i) over the criteria available in the cell,
#                every cell with at least one criterion; green per person NA treated as missing
#   avail80      avail, scored only where >= 80% of the total weight is available
#   impute       distance indicators (recreation distance, blue space distance, walking time to
#                green) filled with the mean of the 8 neighbouring cells where >= 3 neighbours have a
#                value, normalised with the MCDA bounds; full weights where all 10 criteria are then
#                present, the avail rule elsewhere
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/malta_mcda_missing.R

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(sf); library(ggplot2); library(patchwork)
  library(sysfonts); library(showtext)
})
font_add_google("Hanken Grotesk", "hanken")
showtext_auto(); showtext_opts(dpi = 300)
theme_set(theme_void(base_family = "hanken"))
source(here::here("R", "theme_lancet.R"))
lancet_font <- "hanken"

OUT <- here::here("output/figures_mcda/missing_values")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
wcsv <- function(x, f) readr::write_csv(x, file.path(OUT, f))
save_fig <- function(p, name, h, w) {
  f <- c(save_figure_lancet(p, name, OUT, height_mm = h, width_mm = w),
         save_figure_pptx(p, name, OUT, height_mm = h, width_mm = w))
  cat("Saved:", paste(basename(f), collapse = ", "), "\n")
}

# ---- Inputs ---------------------------------------------------------------------------------------
m <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds")) %>% mutate(gid = as.character(gid))
border <- st_sf(geometry = readRDS(here::here("data/malta/malta_union_boundary.rds")), crs = 3035)
pop <- st_read(here::here("data/malta/Population_Malta_reallocated_nso.gpkg"), quiet = TRUE) %>%
  st_drop_geometry() %>% transmute(gid = as.character(gid), pop_nso = pop_reallocated_nso)
m <- m %>% left_join(pop, by = "gid")
stopifnot(nrow(m) == 10657, !anyNA(m$pop_nso))

crit <- tibble::tribble(
  ~norm,             ~raw,                                ~label,
  "norm_lst",        "lst",                               "Land surface temperature",
  "norm_imd",        "imd",                               "Imperviousness",
  "norm_dist_bs",    "dist_bs",                           "Distance to blue space",
  "norm_Lden",       "Lden",                              "Noise (Lden)",
  "norm_traffic",    "new_trafficvol",                    "Traffic",
  "norm_no2",        "no2_avg_21",                        "NO2",
  "norm_tree",       "perc_tree",                         "Street tree cover",
  "norm_green_time", "nearest_green_min",                 "Walking time to green",
  "norm_dist_rec",   "walk_dist_m",                       "Distance to recreation",
  "norm_green_exp",  "green_m2_e2sfca_per_person_gauss",  "Green per person (E2SFCA)")
nv <- crit$norm

# Citizen weights recovered exactly from the saved score
d0 <- st_drop_geometry(m)
fit <- lm(reformulate(nv, "priority_citizen", intercept = FALSE), data = filter(d0, !is.na(priority_citizen)))
w <- coef(fit)[nv]
stopifnot(max(abs(residuals(fit))) < 1e-8, abs(sum(w) - 1) < 1e-8)
crit$weight <- unname(w)

# Normalised scores with missing values as NA (green per person: raw NA -> NA, not 0)
S <- as.matrix(d0[, nv])
S[, "norm_green_exp"][is.na(d0$green_m2_e2sfca_per_person_gauss)] <- NA
miss <- is.na(S)

# ---- 1. Missing values per indicator --------------------------------------------------------------
popd <- d0$pop_nso > 0
q1 <- crit %>% mutate(
  missing_cells = colSums(miss), missing_pct = round(100 * missing_cells / nrow(S), 2),
  missing_populated_cells = colSums(miss[popd, , drop = FALSE]),
  residents_in_missing_cells = round(colSums(miss * d0$pop_nso)),
  weight_pct = round(100 * weight, 1)) %>% select(-norm, -weight)
wcsv(q1, "q1_missing_by_indicator.csv"); print(as.data.frame(q1))

n_miss <- rowSums(miss)
w_avail <- as.numeric((!miss) %*% w)
q1b <- tibble(n_missing = n_miss, populated = popd, pop = d0$pop_nso) %>%
  group_by(n_missing) %>% summarise(cells = n(), populated_cells = sum(populated), residents = round(sum(pop)), .groups = "drop")
q1c <- tibble(pct_weight_missing = round(100 * (1 - w_avail), 1), populated = popd, pop = d0$pop_nso,
              combo = apply(miss, 1, function(r) if (!any(r)) "none" else paste(crit$label[r], collapse = " + "))) %>%
  group_by(pct_weight_missing, combo) %>%
  summarise(cells = n(), populated_cells = sum(populated), residents = round(sum(pop)), .groups = "drop") %>%
  arrange(pct_weight_missing)
wcsv(q1b, "q1_cells_by_number_missing.csv"); wcsv(q1c, "q1_cells_by_weight_missing.csv")
print(as.data.frame(q1b)); print(as.data.frame(q1c))

# ---- 2. Where are the gaps? -----------------------------------------------------------------------
edge <- st_cast(st_union(border), "MULTILINESTRING")
ctr <- st_centroid(st_geometry(m))
d0$dist_edge_m <- as.numeric(st_distance(ctr, edge))
d0$any_missing <- n_miss > 0
loc <- d0 %>% mutate(group = ifelse(any_missing, "cells with a missing criterion", "complete cells")) %>%
  group_by(group) %>%
  summarise(cells = n(), median_dist_to_study_edge_m = median(dist_edge_m),
            pct_within_200m_of_edge = 100 * mean(dist_edge_m <= 200),
            median_dist_blue_space_m = median(dist_bs), pct_within_100m_of_blue = 100 * mean(dist_bs <= 100),
            pct_populated = 100 * mean(pop_nso > 0), .groups = "drop") %>%
  mutate(across(where(is.double), ~ round(., 1)))
by_council <- d0 %>% group_by(local_council = NAME) %>%
  summarise(cells = n(), cells_missing = sum(any_missing), pct_missing = 100 * mean(any_missing),
            missing_walk_time = sum(miss[cur_group_rows(), "norm_green_time"]),
            missing_recreation = sum(miss[cur_group_rows(), "norm_dist_rec"]),
            residents_missing = sum(pop_nso[any_missing]), .groups = "drop") %>%
  mutate(share_of_all_missing_pct = 100 * cells_missing / sum(cells_missing)) %>%
  arrange(desc(cells_missing)) %>% mutate(across(where(is.double), ~ round(., 1)))
wcsv(loc, "q2_missing_location_summary.csv"); wcsv(by_council, "q2_missing_by_council.csv")
print(as.data.frame(loc)); print(as.data.frame(head(by_council, 12)))

# Maps: one per indicator + number of missing criteria
bb <- st_bbox(border)
base_map <- function() list(
  geom_sf(data = border, fill = "grey92", colour = NA),
  geom_sf(data = border, fill = NA, colour = "grey25", linewidth = 0.15),
  coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], datum = NA),
  theme_lancet_map())
small <- lapply(seq_along(nv), function(k) {
  mc <- m[miss[, k], ]
  ttl <- sprintf("%s\n%d cells missing", crit$label[k], sum(miss[, k]))
  p <- ggplot() + base_map()
  if (nrow(mc) > 0) p <- p + geom_sf(data = mc, fill = "#c0392b", colour = NA)
  p + labs(subtitle = ttl) + theme(plot.subtitle = element_text(size = 6.5), plot.margin = margin(2, 2, 2, 2))
})
p_small <- wrap_plots(small, ncol = 5) +
  plot_annotation(caption = "Red: cells with a missing value. Grey: study area.",
                  theme = theme(plot.caption = element_text(family = lancet_font, size = 6.5, hjust = 0)))
save_fig(p_small, "missing_by_indicator_Malta", h = 95, w = LANCET_W2)

m$n_missing <- factor(n_miss, levels = sort(unique(n_miss)))
cnt_col <- c("0" = "grey88", "1" = "#f4a582", "2" = "#d6604d", "3" = "#67001f")
lay <- m %>% select(quint_label = n_missing)
lay_d <- lay %>% st_buffer(0.5) %>% st_set_agr("constant") %>% st_intersection(st_union(border)) %>%
  st_collection_extract("POLYGON") %>% group_by(quint_label) %>% summarise(.groups = "drop")
p_cnt <- ggplot() +
  geom_sf(data = lay_d, aes(fill = quint_label), colour = NA) +
  geom_sf(data = border, fill = NA, colour = "grey25", linewidth = 0.2) +
  scale_fill_manual(values = cnt_col[levels(m$n_missing)], name = "Missing criteria per cell") +
  lancet_scale_bar("bl") + lancet_north_arrow("tr") +
  coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], datum = NA) +
  guides(fill = guide_legend(nrow = 1)) + theme_lancet_map() +
  theme(legend.position = "bottom", legend.title.position = "top", legend.key.size = unit(3, "mm"),
        plot.margin = margin(3, 3, 3, 3))
save_fig(p_cnt, "missing_count_map_Malta", h = 95, w = LANCET_W1)

# ---- 3. Available weight rule ---------------------------------------------------------------------
score_avail <- function(S, w) {
  A <- !is.na(S); S0 <- S; S0[!A] <- 0
  num <- as.numeric(S0 %*% w); den <- as.numeric(A %*% w)
  ifelse(den > 0, num / den, NA)
}
eq_avail <- function(S) rowMeans(S, na.rm = TRUE)
d0$weight_available <- w_avail
d0$priority_avail <- score_avail(S, w)
d0$priority_avail80 <- ifelse(w_avail >= 0.8, d0$priority_avail, NA)
d0$equal_avail <- eq_avail(S)
d0$equal_avail80 <- ifelse(w_avail >= 0.8, d0$equal_avail, NA)
# Check: on complete cells the rule gives the saved score
cc <- n_miss == 0
stopifnot(max(abs(d0$priority_avail[cc] - d0$priority_citizen[cc])) < 1e-9)
cat("\npriority_avail:\n"); print(summary(d0$priority_avail)); cat("weight_available:\n"); print(summary(d0$weight_available))

# ---- 4. Neighbour imputation of distance indicators ----------------------------------------------
xy <- st_coordinates(ctr)
ix <- round((xy[, 1] - min(xy[, 1])) / 100); iy <- round((xy[, 2] - min(xy[, 2])) / 100)
key <- paste(ix, iy); stopifnot(!anyDuplicated(key))
nb_idx <- lapply(seq_len(nrow(xy)), function(i) {
  k <- paste(ix[i] + c(-1, 0, 1, -1, 1, -1, 0, 1), iy[i] + c(-1, -1, -1, 0, 0, 1, 1, 1))
  na.omit(match(k, key))
})
fill_nb <- function(x) {
  out <- x
  for (i in which(is.na(x))) {
    v <- x[nb_idx[[i]]]; v <- v[!is.na(v)]
    if (length(v) >= 3) out[i] <- mean(v)
  }
  out
}
nm <- function(x, lo, hi) (pmax(pmin(x, hi), lo) - lo) / (hi - lo)
p98_time <- quantile(d0$nearest_green_min, 0.98, na.rm = TRUE)
p98_rec  <- quantile(d0$walk_dist_m, 0.98, na.rm = TRUE)
p98_bs   <- quantile(d0$dist_bs, 0.98, na.rm = TRUE)
# Bounds check against the saved normalised values
stopifnot(max(abs(nm(d0$nearest_green_min, 0, p98_time) - d0$norm_green_time), na.rm = TRUE) < 1e-9,
          max(abs(nm(d0$walk_dist_m, 300, p98_rec) - d0$norm_dist_rec), na.rm = TRUE) < 1e-9,
          max(abs(nm(d0$dist_bs, 0, p98_bs) - d0$norm_dist_bs), na.rm = TRUE) < 1e-9)
t_f <- fill_nb(d0$nearest_green_min); r_f <- fill_nb(d0$walk_dist_m); b_f <- fill_nb(d0$dist_bs)
S_imp <- S
S_imp[, "norm_green_time"] <- nm(t_f, 0, p98_time)
S_imp[, "norm_dist_rec"]   <- nm(r_f, 300, p98_rec)
S_imp[, "norm_dist_bs"]    <- nm(b_f, 0, p98_bs)
q4 <- tibble(indicator = c("Walking time to green", "Distance to recreation", "Distance to blue space"),
             missing_before = c(sum(is.na(d0$nearest_green_min)), sum(is.na(d0$walk_dist_m)), sum(is.na(d0$dist_bs))),
             filled = c(sum(is.na(d0$nearest_green_min) & !is.na(t_f)), sum(is.na(d0$walk_dist_m) & !is.na(r_f)),
                        sum(is.na(d0$dist_bs) & !is.na(b_f))),
             still_missing = c(sum(is.na(t_f)), sum(is.na(r_f)), sum(is.na(b_f))))
complete_imp <- rowSums(is.na(S_imp)) == 0
q4 <- bind_rows(q4, tibble(indicator = "Cells complete after filling (scored with full weights)",
                           missing_before = sum(n_miss > 0), filled = sum(complete_imp & n_miss > 0),
                           still_missing = sum(!complete_imp)))
wcsv(q4, "q4_neighbour_imputation.csv"); print(as.data.frame(q4))
d0$priority_impute <- ifelse(complete_imp, as.numeric(replace(S_imp, is.na(S_imp), 0) %*% w), score_avail(S_imp, w))
d0$equal_impute <- eq_avail(S_imp)
cat("priority_impute:\n"); print(summary(d0$priority_impute))

# ---- 5. Comparison with the current score ---------------------------------------------------------
# Quintiles (ntile, as in the priority maps) are computed over each score's own set of cells
quint <- function(x) { q <- rep(NA_integer_, length(x)); ok <- !is.na(x); q[ok] <- ntile(x[ok], 5); q }
cmp <- function(new, name) {
  qc <- quint(d0$priority_citizen); qn <- quint(new); both <- !is.na(qc) & !is.na(qn)
  tibble(variant = name, cells_scored = sum(!is.na(new)), cells_added = sum(!is.na(new) & is.na(d0$priority_citizen)),
         cells_in_both = sum(both),
         spearman = cor(new[both], d0$priority_citizen[both], method = "spearman"),
         top_quintile_retained_pct = 100 * sum(qc[both] == 5 & qn[both] == 5) / sum(qc[both] == 5),
         cells_changing_quintile_pct = 100 * mean(qc[both] != qn[both]),
         added_cells_in_top_quintile = sum(qn == 5 & is.na(d0$priority_citizen), na.rm = TRUE))
}
q5 <- bind_rows(cmp(d0$priority_avail, "Available weight rule (all cells with >= 1 criterion)"),
                cmp(d0$priority_avail80, "Available weight rule, >= 80% of weight available"),
                cmp(d0$priority_impute, "Neighbour imputation of distance indicators")) %>%
  mutate(across(where(is.double), ~ round(., 3)))
wcsv(q5, "q5_comparison_with_current.csv"); print(as.data.frame(q5))

# ---- 6. Minimum data rule -------------------------------------------------------------------------
q6 <- bind_rows(lapply(c(0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 1), function(t)
  tibble(min_weight_available_pct = 100 * t, cells_below = sum(w_avail < t - 1e-12),
         populated_cells_below = sum(w_avail < t - 1e-12 & popd),
         residents_below = round(sum(d0$pop_nso[w_avail < t - 1e-12])),
         cells_scored = sum(w_avail >= t - 1e-12))))
wcsv(q6, "q6_minimum_data_rule.csv"); print(as.data.frame(q6))

# Cell level output (alongside, not replacing, the MCDA file)
readr::write_csv(d0 %>% transmute(gid, local_council = NAME, pop_nso, n_missing = n_miss,
                                  weight_available = round(weight_available, 4), priority_citizen,
                                  priority_avail, priority_avail80, priority_impute, equal_avail, equal_avail80),
                 file.path(OUT, "malta_priority_missing_variants.csv"))

# ---- 7. Priority map for the recommended variant + poster numbers --------------------------------
REC <- "priority_avail80"
quint_colours <- c("Q1 (lowest)" = "#1a9641", "Q2" = "#a6d96a", "Q3" = "#ffffbf", "Q4" = "#fdae61",
                   "Q5 (highest)" = "#d73027")
map_df <- m %>% select(gid) %>% mutate(score = d0[[REC]], quint = quint(score),
  quint_label = case_when(is.na(quint) ~ "No score", quint == 1 ~ "Q1 (lowest)", quint == 5 ~ "Q5 (highest)",
                          TRUE ~ paste0("Q", quint)),
  quint_label = factor(quint_label, levels = c(names(quint_colours), "No score")))
lay <- map_df %>% select(quint_label) %>% st_buffer(0.5) %>% st_set_agr("constant") %>%
  st_intersection(st_union(border)) %>% st_collection_extract("POLYGON") %>%
  group_by(quint_label) %>% summarise(.groups = "drop")
p_rec <- ggplot() +
  geom_sf(data = lay, aes(fill = quint_label), colour = NA) +
  geom_sf(data = border, fill = NA, colour = "grey25", linewidth = 0.2) +
  scale_fill_manual(values = c(quint_colours, "No score" = "grey88"), name = "Priority quintile", drop = FALSE) +
  lancet_scale_bar("bl") + lancet_north_arrow("tr") +
  coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], datum = NA) +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE)) + theme_lancet_map() +
  theme(legend.position = "bottom", legend.title.position = "top", legend.key.size = unit(3, "mm"),
        plot.margin = margin(3, 3, 3, 3))
save_fig(p_rec, "Figure_priority_map_Malta_lancet_avail80", h = 95, w = LANCET_W1)
print(table(map_df$quint_label))

# Poster numbers: current vs recommended
poster_nums <- function(score, eq, name) {
  qn <- quint(score); top <- qn == 5 & !is.na(qn)
  hot <- d0 %>% mutate(top = top, scored = !is.na(score)) %>% filter(scored) %>%
    group_by(local_council = NAME) %>%
    summarise(cells = n(), top_cells = sum(top), pct_cells_top = 100 * mean(top),
              top_residents_nso = sum(pop_nso[top]), .groups = "drop") %>%
    filter(cells >= 20) %>% arrange(desc(pct_cells_top)) %>% mutate(rank = row_number(), variant = name)
  ctb <- tibble(indicator = crit$label, weight = w,
                mean_norm = colMeans(S[top, , drop = FALSE], na.rm = TRUE)) %>%
    mutate(contribution = mean_norm * weight, share_pct = 100 * contribution / sum(contribution), variant = name) %>%
    arrange(desc(contribution))
  ok <- !is.na(score) & !is.na(eq)
  qe <- quint(ifelse(ok, eq, NA)); qs <- quint(ifelse(ok, score, NA))
  rob <- tibble(variant = name, cells = sum(ok),
                pearson_citizen_vs_equal = cor(score[ok], eq[ok]),
                spearman_citizen_vs_equal = cor(score[ok], eq[ok], method = "spearman"),
                top_quintile_overlap_pct = 100 * sum(qs == 5 & qe == 5, na.rm = TRUE) / sum(qs == 5, na.rm = TRUE),
                top_quintile_cells = sum(top), top_quintile_residents_nso = sum(d0$pop_nso[top]))
  list(hot = hot, ctb = ctb, rob = rob)
}
pc <- poster_nums(d0$priority_citizen, ifelse(is.na(d0$priority_citizen), NA, d0$priority_equal), "current")
pr <- poster_nums(d0$priority_avail80, d0$equal_avail80, "avail80")
hot2 <- full_join(pc$hot %>% select(local_council, rank_current = rank, pct_top_current = pct_cells_top),
                  pr$hot %>% select(local_council, rank_avail80 = rank, pct_top_avail80 = pct_cells_top),
                  by = "local_council") %>% arrange(rank_avail80) %>% mutate(across(where(is.double), ~ round(., 1)))
ctb2 <- full_join(pc$ctb %>% select(indicator, share_current_pct = share_pct),
                  pr$ctb %>% select(indicator, share_avail80_pct = share_pct), by = "indicator") %>%
  arrange(desc(share_avail80_pct)) %>% mutate(across(where(is.double), ~ round(., 1)))
rob2 <- bind_rows(pc$rob, pr$rob) %>% mutate(across(where(is.double), ~ round(., 3)))
wcsv(hot2, "q7_hotspot_councils_current_vs_avail80.csv")
wcsv(ctb2, "q7_top_quintile_drivers_current_vs_avail80.csv")
wcsv(rob2, "q7_citizen_vs_equal_current_vs_avail80.csv")
print(as.data.frame(head(hot2, 12))); print(as.data.frame(ctb2)); print(as.data.frame(rob2))
cat("\nAll outputs in", OUT, "\n")
