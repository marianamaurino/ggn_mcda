# Effect of the 2026-11-19 changes on the priority scores, WITHOUT re-running the MCDA notebooks
# (instructed: do not rerun the full MCDA yet). Writes nothing to data/.
#   Klagenfurt: (1) one row per cell (12,418; caps p2/p98 now computed on cells, not on 12,751 rows);
#               (2) walking time to green continuous, min-max capped at p98 (was 4 classes).
#   Malta:      street greenery cap = p98 of the data (11.70%) instead of the hardcoded 14.18%.
# Scores are recomputed from the saved score files with the notebooks' normalisation code and the
# available weight rule; weights are recovered from the saved score (exact on complete cells, checked).
# Comparison (spec 5.1, 5.2): Spearman over cells scored in both versions; % of the current top
# quintile cells that stay in the top quintile. Quintiles of the current version as the current
# figures compute them (ntile over the rows of the saved file).
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/score_change_2026_11_19.R

suppressPackageStartupMessages({ library(sf); library(dplyr) })

normalize_minmax <- function(x, lower = NULL, upper = NULL) {
  if (is.null(lower)) lower <- min(x, na.rm = TRUE)
  if (is.null(upper)) upper <- max(x, na.rm = TRUE)
  x <- pmin(x, upper); x <- pmax(x, lower)
  (x - lower) / (upper - lower)
}
q <- function(x, p) unname(quantile(x, p, na.rm = TRUE))

# available weight rule (>= 80% of weight), spec 4.2
wlc_avail <- function(df, w, min_w = 0.8) {
  S <- as.matrix(df[, names(w)]); W <- matrix(w, nrow(S), length(w), byrow = TRUE)
  W[is.na(S)] <- 0; S[is.na(S)] <- 0
  wa <- rowSums(W)
  ifelse(wa >= min_w * sum(w), rowSums(W * S) / wa, NA_real_)
}
recover_w <- function(df, vars) {
  cc <- df[complete.cases(df[, c(vars, "priority_citizen")]), ]
  fit <- lm(reformulate(vars, "priority_citizen", intercept = FALSE), data = cc)
  w <- coef(fit); cat("  weights recovered, max |residual|", signif(max(abs(resid(fit))), 2),
                      "| sum", round(sum(w), 6), "\n"); w
}
compare <- function(old, new, q_old, label) {
  ok <- !is.na(old) & !is.na(new)
  q_new <- rep(NA_integer_, length(new)); q_new[!is.na(new)] <- ntile(new[!is.na(new)], 5)
  top_old <- which(q_old == 5)
  tibble(change = label,
         scored_old = sum(!is.na(old)), scored_new = sum(!is.na(new)),
         spearman = round(cor(old[ok], new[ok], method = "spearman"), 3),
         top_q_retained_pct = round(100 * mean(q_new[top_old] == 5, na.rm = TRUE), 1),
         cells_changing_quintile_pct = round(100 * mean(q_old[ok] != q_new[ok]), 1))
}

# ---- Klagenfurt ---------------------------------------------------------------------------
cat("== Klagenfurt ==\n")
k_rows <- readRDS(here::here("data/klagenfurt/klagenfurt_mcda_priority_may.rds")) %>% st_drop_geometry()
cat("  saved score file:", nrow(k_rows), "rows,", n_distinct(k_rows$ID), "cells; scored rows",
    sum(!is.na(k_rows$priority_citizen)), "| scored cells",
    n_distinct(k_rows$ID[!is.na(k_rows$priority_citizen)]), "\n")
# current quintiles as in the figures and tables (ntile over the rows), then one row per cell
k_rows$q_cur <- NA_integer_
ok <- !is.na(k_rows$priority_citizen); k_rows$q_cur[ok] <- ntile(k_rows$priority_citizen[ok], 5)
k <- k_rows %>% distinct(ID, .keep_all = TRUE)
kvars <- c("norm_lst", "norm_dist_bs", "norm_no2", "norm_pm25", "norm_green_time",
           "norm_traffic_cat", "norm_income_weighted")
wk <- recover_w(k, kvars)
stopifnot(max(abs(wlc_avail(k, wk) - k$priority_citizen), na.rm = TRUE) < 1e-9)

norm_k <- function(d, green = c("classes", "continuous")) {
  green <- match.arg(green)
  d %>% mutate(
    norm_lst = normalize_minmax(lst, min(lst, na.rm = TRUE), q(lst, 0.98)),
    norm_dist_bs = normalize_minmax(dist_bs, 0, q(dist_bs, 0.98)),
    norm_no2 = normalize_minmax(log1p(no2_final), log1p(min(no2_final, na.rm = TRUE)),
                                log1p(q(no2_final, 0.98))),
    norm_pm25 = normalize_minmax(pm25_final, min(pm25_final, na.rm = TRUE), q(pm25_final, 0.98)),
    norm_green_time = if (green == "classes") {
      case_when(is.na(nearest_green_min) ~ NA_real_, nearest_green_min <= 5 ~ 0,
                nearest_green_min <= 10 ~ 0.33, nearest_green_min <= 15 ~ 0.67, TRUE ~ 1)
    } else normalize_minmax(nearest_green_min, 0, q(nearest_green_min, 0.98)),
    norm_traffic_cat = case_when(new_trafficvol <= 7 ~ 0, new_trafficvol <= 564 ~ 0.5, TRUE ~ 1),
    norm_income_weighted = 1 - normalize_minmax(income_weighted, q(income_weighted, 0.02),
                                                q(income_weighted, 0.98)))
}
# reproduction check: same code on the 12,751 rows gives the saved norms
rep_rows <- norm_k(k_rows, "classes")
cat("  reproduction on rows, max |diff| over norms:",
    signif(max(sapply(kvars, function(v) max(abs(rep_rows[[v]] - k_rows[[v]]), na.rm = TRUE))), 2), "\n")

k1 <- norm_k(k, "classes");    s1 <- wlc_avail(k1, wk)
k2 <- norm_k(k, "continuous"); s2 <- wlc_avail(k2, wk)
cat("  p98 walking time (cells):", round(q(k$nearest_green_min, 0.98), 2), "min\n")
res_k <- bind_rows(
  compare(k$priority_citizen, s1, k$q_cur, "1 deduplicated cells only"),
  compare(k$priority_citizen, s2, k$q_cur, "1 + 2 walking time continuous (new score)"))
print(as.data.frame(res_k))
# deduplication alone, holding the score fixed: quintiles over cells vs over rows
q_cells <- rep(NA_integer_, nrow(k)); okc <- !is.na(k$priority_citizen)
q_cells[okc] <- ntile(k$priority_citizen[okc], 5)
cat("  same score, quintiles over cells vs rows: cells changing quintile",
    sum(q_cells != k$q_cur, na.rm = TRUE), "of", sum(okc), "\n")

# ---- Malta --------------------------------------------------------------------------------
cat("\n== Malta ==\n")
m <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds")) %>% st_drop_geometry()
mvars <- c("norm_lst", "norm_imd", "norm_dist_bs", "norm_Lden", "norm_traffic", "norm_no2",
           "norm_tree", "norm_green_time", "norm_dist_rec", "norm_green_exp")
wm <- recover_w(m, mvars)
eligible <- !(is.na(m$priority_citizen) & !is.na(wlc_avail(m, wm)))   # airport and port cells
cat("  not eligible cells:", sum(!eligible), "\n")
s_cur <- ifelse(eligible, wlc_avail(m, wm), NA)
stopifnot(max(abs(s_cur - m$priority_citizen), na.rm = TRUE) < 1e-9)
stopifnot(max(abs(m$norm_tree - (1 - normalize_minmax(m$perc_tree, 0, 14.18)))) < 1e-12)
p98_tree <- q(m$perc_tree, 0.98)
cat("  p98 perc_tree:", round(p98_tree, 2), "% (was 14.18)\n")
m_new <- m %>% mutate(norm_tree = 1 - normalize_minmax(perc_tree, 0, p98_tree))
s_new <- ifelse(eligible, wlc_avail(m_new, wm), NA)
qm <- rep(NA_integer_, nrow(m)); okm <- !is.na(m$priority_citizen)
qm[okm] <- ntile(m$priority_citizen[okm], 5)
print(as.data.frame(compare(m$priority_citizen, s_new, qm, "street greenery cap p98 = 11.70%")))
cat("  cells whose norm_tree changes:", sum(abs(m_new$norm_tree - m$norm_tree) > 1e-12), "\n")
