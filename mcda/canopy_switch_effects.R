# Effect of the street greenery switch (Street Tree Layer 2018 -> street canopy, spec 3.6, 2026-11-23)
# on the Malta score: old = data/malta/malta_mcda_processed_realloc_pre_canopy.rds, new = the main file.
# Consistency check against mcda/street_greenery_canopy_malta.Rmd Step 7a (option b, linear), then the
# old vs new report. Outputs: output/figures_mcda/canopy_switch_2026_11_23/.
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 MKL_NUM_THREADS=4 \
#      nice -n 10 Rscript mcda/canopy_switch_effects.R

suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(sf); library(purrr) })
OUT <- here::here("output/figures_mcda/canopy_switch_2026_11_23")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
SEED <- 20261120; N_PERM <- 200

old <- readRDS(here::here("data/malta/malta_mcda_processed_realloc_pre_canopy.rds")) %>% st_drop_geometry()
new <- readRDS(here::here("data/malta/malta_mcda_processed_realloc.rds")) %>% st_drop_geometry()
stopifnot(nrow(old) == 10657, nrow(new) == 10657, identical(as.character(old$gid), as.character(new$gid)))

m_vars <- c("norm_lst", "norm_imd", "norm_dist_bs", "norm_Lden", "norm_traffic", "norm_no2", "norm_tree",
            "norm_green_time", "norm_dist_rec", "norm_green_exp")
m_lab  <- c(norm_lst = "Urban heat", norm_imd = "Grey infrastructure", norm_dist_bs = "Blue space",
            norm_Lden = "Noise", norm_traffic = "Traffic", norm_no2 = "Air quality", norm_tree = "Street greenery",
            norm_green_time = "Green proximity", norm_dist_rec = "Recreation", norm_green_exp = "Green per person")

# Citizen weights recovered from each score (no intercept, exact)
get_w <- function(d) {
  cc <- d[complete.cases(d[, m_vars]) & !is.na(d$priority_citizen), ]
  f <- lm(reformulate(m_vars, "priority_citizen", intercept = FALSE), data = cc)
  stopifnot(max(abs(residuals(f))) < 1e-8)
  coef(f)[m_vars]
}
w_old <- get_w(old); w_new <- get_w(new)
stopifnot(max(abs(w_old - w_new)) < 1e-10)
w <- w_new

wlc <- function(d, w, keep) {
  S <- as.matrix(d[, names(w)]); A <- !is.na(S); S[!A] <- 0
  out <- as.numeric(S %*% w) / as.numeric(A %*% w); out[!keep] <- NA; out
}
top_q <- function(p) { q <- rep(NA_integer_, length(p)); q[!is.na(p)] <- ntile(p[!is.na(p)], 5); q }
pair <- function(a, b, subset = rep(TRUE, length(a))) {
  qa <- top_q(a); qb <- top_q(b); k <- !is.na(a) & !is.na(b) & subset
  tibble(cells = sum(k), spearman = cor(a[k], b[k], method = "spearman"),
         top_quintile_overlap_pct = 100 * sum(qa == 5 & qb == 5 & k) / sum(qa == 5 & k),
         cells_changing_quintile_pct = 100 * mean(qa[k] != qb[k]))
}
popd <- new$Total_Population > 0

# ---- Step 5. Consistency check against the test notebook (Step 7a, option b, linear) ---------
pc <- pair(old$priority_citizen, new$priority_citizen)
council_top <- function(d, p) tibble(NAME = d$NAME, q = top_q(p)) %>% filter(!is.na(q)) %>%
  group_by(NAME) %>% summarise(cells = n(), top_quintile_pct = 100 * mean(q == 5), .groups = "drop") %>%
  arrange(desc(top_quintile_pct))
top_new <- council_top(new, new$priority_citizen) %>% slice(1:5)
top_old <- council_top(old, old$priority_citizen) %>% slice(1:5)

topclass <- function(S) apply(S, 2, function(x) {
  q <- quantile(x, 0.8, na.rm = TRUE); t <- !is.na(x) & x >= q
  if (mean(t[!is.na(x)]) > 0.25) t <- !is.na(x) & x > q
  t
})
step3 <- function(d, nm) {
  S <- as.matrix(d[d$scored, m_vars]); tc <- topclass(S); obs <- rowSums(tc)
  set.seed(SEED); perm <- replicate(N_PERM, mean(rowSums(apply(tc, 2, sample)) >= 3))
  tibble(score = nm, scored_cells = nrow(S), street_greenery_top_class_pct = 100 * mean(tc[, "norm_tree"]),
         top_3plus_pct = 100 * mean(obs >= 3), top_3plus_pct_shuffled = 100 * mean(perm),
         ratio_to_shuffled = mean(obs >= 3) / mean(perm))
}
s3 <- bind_rows(step3(old, "Old (Street Tree Layer)"), step3(new, "New (street canopy)"))

check <- tibble(
  item = c("Scored cells", "Spearman with the old score", "Top quintile overlap (%)", "Top 5 councils", "Step 3 ratio"),
  expected = c("10194", "0.811", "82.7", "HAMRUN, SANTA VENERA, MARSA, BIRKIRKARA, MSIDA", "0.989"),
  observed = c(as.character(sum(new$scored)), sprintf("%.3f", pc$spearman), sprintf("%.1f", pc$top_quintile_overlap_pct),
               paste(top_new$NAME, collapse = ", "), sprintf("%.3f", s3$ratio_to_shuffled[2]))) %>%
  mutate(ok = expected == observed)
print(as.data.frame(check), row.names = FALSE)
readr::write_csv(check, file.path(OUT, "consistency_check.csv"))
if (!all(check$ok)) stop("Consistency check failed: see consistency_check.csv")

# ---- Step 6. Old vs new ---------------------------------------------------------------------
agree <- bind_rows(pc %>% mutate(set = "All scored cells", .before = 1),
                   pair(old$priority_citizen, new$priority_citizen, popd) %>% mutate(set = "Populated scored cells", .before = 1))

contrib <- function(d) {
  q <- top_q(d$priority_citizen); top <- which(q == 5)
  c5 <- colMeans(as.matrix(d[top, m_vars]), na.rm = TRUE) * w
  tibble(criterion = m_lab[m_vars], weight_pct = 100 * w, share_top_quintile_pct = 100 * c5 / sum(c5))
}
shares <- contrib(old) %>% rename(old_pct = share_top_quintile_pct) %>%
  left_join(contrib(new) %>% select(criterion, new_pct = share_top_quintile_pct), by = "criterion") %>%
  mutate(change_pp = new_pct - old_pct) %>% arrange(desc(new_pct))

pop_q5 <- function(d) { q <- top_q(d$priority_citizen)
  100 * sum(d$Total_Population[q %in% 5]) / sum(d$Total_Population[d$scored]) }
pop_tab <- tibble(score = c("Old", "New"), population_in_top_quintile_pct = c(pop_q5(old), pop_q5(new)),
                  population_in_top_quintile = c(sum(old$Total_Population[top_q(old$priority_citizen) %in% 5]),
                                                 sum(new$Total_Population[top_q(new$priority_citizen) %in% 5])))

eq <- bind_rows(pair(old$priority_citizen, old$priority_equal) %>% mutate(score = "Old", .before = 1),
                pair(new$priority_citizen, new$priority_equal) %>% mutate(score = "New", .before = 1))

loo <- function(d, nm) map_dfr(m_vars, function(v) {
  ww <- w[m_vars != v]
  pair(d$priority_citizen, wlc(d, ww / sum(ww), d$scored)) %>%
    mutate(score = nm, criterion_dropped = m_lab[[v]], .before = 1)
})
loo_tab <- bind_rows(loo(old, "Old"), loo(new, "New")) %>%
  select(score, criterion_dropped, spearman, top_quintile_overlap_pct) %>%
  pivot_wider(names_from = score, values_from = c(spearman, top_quintile_overlap_pct)) %>%
  arrange(spearman_New)

councils <- bind_cols(top_old %>% transmute(rank = 1:5, old = NAME, old_pct = top_quintile_pct),
                      top_new %>% transmute(new = NAME, new_pct = top_quintile_pct))

res <- list(agreement = agree, councils = councils, criterion_shares = shares, population = pop_tab,
            citizen_vs_equal = eq, leave_one_out = loo_tab, step3 = s3)
iwalk(res, function(x, nm) {
  cat("\n==", nm, "\n"); print(as.data.frame(mutate(x, across(where(is.double), ~ round(., 3)))), row.names = FALSE)
  readr::write_csv(x, file.path(OUT, paste0(nm, ".csv")))
})
