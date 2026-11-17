# WP6 deck, November 2026: green accessibility and closed survey questions, Malta and Klagenfurt.
#
# Reads only saved outputs:
#   Malta:      data/malta/accessibility_malta/own_routing/ (mcda/malta_e2sfca_newpop.R),
#               population = GHSL reallocated, NSO Census 2021 (pop_nso)
#   Klagenfurt: data/klagenfurt/accessibility_klagenfurt/own_routing/ (mcda/klagenfurt_e2sfca_newpop.R),
#               population = census grid (popdense_2020, one row per cell)
#   Surveys:    data/malta/maltasurvey_jun26.xlsx, data/klagenfurt/klagenfurtsurvey_nov26.xlsx (R/read_survey.R)
# Green: Urban Atlas 2021 classes 14110, 14130, 31000, 40000, patches >= 500 m2 (and >= 0.5 ha), both cities.
# Walking times: own OSM routing, 5 km/h, mean over the origin points of each cell (ATGreen aggregation).
# Writes CSVs and summary.md to output/wp6_nov2026/.
#
# Run: OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 FLEXIBLAS_NUM_THREADS=4 nice -n 10 Rscript mcda/wp6_nov2026_numbers.R

suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(sf); library(arrow) })
OUT <- here::here("output/wp6_nov2026")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
wcsv <- function(x, f) { readr::write_csv(x, file.path(OUT, f), na = ""); invisible(x) }
wkb_sf <- function(d, crs = 3035) st_sf(d %>% select(-geometry),
                                        geometry = st_as_sfc(structure(as.list(d$geometry), class = "WKB"), crs = crs))

# ---- Malta: nearest green >= 500 m2 and >= 0.5 ha, step E2SFCA (15 min and 10 min cut) ----------
M_DIR <- here::here("data/malta/accessibility_malta/own_routing")
ATG   <- here::here("accessibility_schifanella/exposure")
mc <- readr::read_csv(file.path(M_DIR, "e2sfca_own_routing_cells.csv"), show_col_types = FALSE,
                      col_types = readr::cols(gid = "c"))
tt <- readRDS(file.path(M_DIR, "travel_times_min.rds"))
mg <- as.data.frame(read_parquet(file.path(ATG, "intermediate/green/green_urban_atlas.parquet")))
stopifnot(identical(tt$gid, mc$gid), identical(as.character(tt$green_id), as.character(mg$green_id)))

# Origin points per cell, rebuilt as in malta_e2sfca_newpop.R (the script saves Tp but not the link)
fm   <- read_parquet(file.path(ATG, "results/final_metrics.parquet")) %>% as.data.frame()
orig <- wkb_sf(read_parquet(file.path(ATG, "results/metrics_origins.parquet")) %>% as.data.frame(), crs = 32633) %>%
  st_transform(3035)
mcells <- fm %>% wkb_sf() %>% transmute(gid = as.character(unit_id), assignment_status, connector_sec)
stopifnot(identical(mcells$gid, mc$gid))
mcells$pt_idx <- st_nearest_feature(mcells, orig)
inside <- st_join(orig %>% select(network_point_id), mcells %>% select(gid), join = st_within)
pts_by_cell <- split(match(inside$network_point_id, orig$network_point_id), inside$gid)
nearest_min_malta <- function(cols) {
  pt <- apply(tt$Tp[, cols, drop = FALSE], 1, min)
  vapply(seq_len(nrow(mcells)), function(i) {
    st <- mcells$assignment_status[i]
    if (st == "direct") {
      p <- pts_by_cell[[mcells$gid[i]]]; if (length(p) == 0) p <- mcells$pt_idx[i]; mean(pt[p])
    } else if (st == "connector") pt[mcells$pt_idx[i]] + mcells$connector_sec[i] / 60 else NA_real_
  }, numeric(1))
}
malta <- mc %>% transmute(gid, assignment_status, pop = pop_nso, step15 = own_step_nso) %>%
  mutate(near_500m2 = nearest_min_malta(rep(TRUE, nrow(mg))),
         near_05ha  = nearest_min_malta(mg$green_ha >= 0.5))
# Check: all patches reproduce the saved own_nearest_sec
stopifnot(max(abs(malta$near_500m2 * 60 - mc$own_nearest_sec), na.rm = TRUE) < 1e-6)

e2sfca_malta <- function(W) {
  Wm <- W(tt$cell_T); Wm[is.na(Wm)] <- 0
  D <- colSums(Wm * malta$pop, na.rm = TRUE); R <- ifelse(D > 0, mg$green_ha * 1e4 / D, 0)
  out <- as.numeric(Wm %*% R); out[malta$assignment_status == "unroutable"] <- NA; out
}
w_step   <- function(t) ifelse(t <= 5, 1, ifelse(t <= 10, 0.7, ifelse(t <= 15, 0.4, 0)))
w_step10 <- function(t) ifelse(t <= 5, 1, ifelse(t <= 10, 0.7, 0))
stopifnot(max(abs(e2sfca_malta(w_step) - malta$step15), na.rm = TRUE) < 1e-6)
malta$step10 <- e2sfca_malta(w_step10)

# ---- Klagenfurt ---------------------------------------------------------------------------------
kc <- readr::read_csv(here::here("data/klagenfurt/accessibility_klagenfurt/own_routing/e2sfca_own_routing_cells.csv"),
                      show_col_types = FALSE, col_types = readr::cols(gid = "c"))
klag <- kc %>% transmute(gid, assignment_status, pop = pop_census, near_500m2 = own_nearest_min_500m2,
                         near_05ha = own_nearest_min_05ha, step15 = own_step_census, step10 = own_step10_census)
stopifnot(!anyDuplicated(klag$gid))

cities <- bind_rows(malta %>% mutate(city = "Malta"), klag %>% mutate(city = "Klagenfurt")) %>%
  filter(pop > 0)

# Sanity checks of the new variables (summary + histogram)
cat("== Populated cells, summaries\n")
print(cities %>% group_by(city) %>% summarise(cells = n(), residents = sum(pop),
                                              across(c(near_500m2, near_05ha, step15, step10),
                                                     ~ median(., na.rm = TRUE), .names = "median_{.col}")))
png(file.path(OUT, "check_histograms.png"), width = 1600, height = 900, res = 150)
par(mfrow = c(2, 3))
for (cty in c("Malta", "Klagenfurt")) {
  d <- filter(cities, city == cty)
  hist(pmin(d$near_500m2, 30), 60, main = paste(cty, "min to green >= 500 m2"), xlab = "min (capped 30)")
  hist(pmin(d$near_05ha, 30), 60, main = paste(cty, "min to green >= 0.5 ha"), xlab = "min (capped 30)")
  hist(log10(1 + d$step15), 60, main = paste(cty, "green m2/person, step"), xlab = "log10(1 + m2)")
}
dev.off()

# ---- 1. Residents within 5, 10, 15 min ------------------------------------------------------------
t1 <- bind_rows(lapply(c("near_500m2", "near_05ha"), function(v) {
  bind_rows(lapply(c(5, 10, 15), function(m) {
    cities %>% group_by(city) %>% summarise(
      green_definition = ifelse(v == "near_500m2", "UA green >= 500 m2", "UA green >= 0.5 ha"),
      walk_min = m,
      residents_total = sum(pop),
      residents_routable = sum(pop[!is.na(.data[[v]])]),
      residents_within = sum(pop[!is.na(.data[[v]]) & .data[[v]] <= m]),
      .groups = "drop")
  }))
})) %>%
  mutate(pct_of_routable = 100 * residents_within / residents_routable,
         pct_of_all = 100 * residents_within / residents_total,
         residents_not_routable = residents_total - residents_routable) %>%
  mutate(city = factor(city, c("Malta", "Klagenfurt"))) %>% arrange(city, green_definition, walk_min) %>%
  mutate(across(c(residents_total, residents_routable, residents_within, residents_not_routable), round),
         across(starts_with("pct"), ~ round(., 1)))
wcsv(t1, "table1_residents_within_walk_of_green.csv")
cat("\n== Table 1\n"); print(as.data.frame(t1))

# ---- 2. Green per person, median and IQR across residents ---------------------------------------
wq <- function(x, w, p) {           # weighted quantile across residents (step function of the weighted ECDF)
  ok <- !is.na(x) & w > 0; x <- x[ok]; w <- w[ok]; o <- order(x); x <- x[o]; cw <- cumsum(w[o]) / sum(w)
  sapply(p, function(pp) x[which(cw >= pp)[1]])
}
step_labels <- c(step15 = "E2SFCA step 1 / 0.7 / 0.4 (0-5 / 5-10 / 10-15 min), headline",
                 step10 = "E2SFCA step 1 / 0.7 (0-5 / 5-10 min), 10 min cut")
t2 <- bind_rows(lapply(names(step_labels), function(v) {
  cities %>% group_by(city) %>% summarise(
    indicator = step_labels[[v]], residents = round(sum(pop[!is.na(.data[[v]])])),
    p25_m2_per_person = wq(.data[[v]], pop, 0.25), median_m2_per_person = wq(.data[[v]], pop, 0.5),
    p75_m2_per_person = wq(.data[[v]], pop, 0.75),
    pct_residents_zero = 100 * sum(pop[.data[[v]] == 0], na.rm = TRUE) / sum(pop[!is.na(.data[[v]])]),
    .groups = "drop")
})) %>% mutate(city = factor(city, c("Malta", "Klagenfurt"))) %>% arrange(indicator, city) %>%
  mutate(across(c(p25_m2_per_person, median_m2_per_person, p75_m2_per_person, pct_residents_zero), ~ round(., 1)))
wcsv(t2, "table2_green_per_person.csv")
cat("\n== Table 2\n"); print(as.data.frame(t2))

# ---- 3. Closed survey questions ----------------------------------------------------------------
source(here::here("R/read_survey.R"))
ms <- read_survey(here::here("data/malta/maltasurvey_jun26.xlsx"))
ks_raw <- read_survey(here::here("data/klagenfurt/klagenfurtsurvey_nov26.xlsx"))
ks <- ks_raw %>% filter(resident != "left-2-plus")   # former residents, as in the Klagenfurt MCDA
stopifnot(nrow(ms) == 123, nrow(ks) == 184)

# Common names: Malta uses kebab case, Klagenfurt camel case
ms <- ms %>% rename(age_group = `age-group`, visit_frequency = `visit-frequency`,
                    visit_reasons = `visit-reasons`, green_nearby = `green-nearby`)
ks <- ks %>% rename(age_group = ageGroup, visit_frequency = visitFrequency,
                    visit_reasons = visitReasons, green_nearby = greenNearby)

# Question labels as in the survey notebooks (mcda/*_survey_results.Rmd); not the verbatim questionnaire
q <- tribble(
  ~variable,         ~question,                                              ~multi,
  "visit_frequency", "How often do you visit green spaces?",                 FALSE,
  "visit_reasons",   "Why do you visit green spaces? (multiple answers)",    TRUE,
  "green_nearby",    "Is there a green space within walking distance?",      FALSE,
  "resident",        "How long have you lived here?",                        FALSE,
  "age_group",       "Age group",                                            FALSE,
  "gender",          "Gender",                                               FALSE,
  "neighborhood",    "Neighbourhood / locality",                             FALSE,
  "language",        "Survey language",                                      FALSE)
labels <- list(
  visit_frequency = c("0" = "Never", "1" = "Once a week", "2-4" = "2-4 times a week", "5-7" = "Daily (5-7 times a week)"),
  visit_reasons   = c(relax = "Relaxation", friends = "Socialising with friends", sport = "Sport"),
  green_nearby    = c(yes = "Yes", no = "No"),
  resident        = c("0-1" = "Less than 1 year", "1-5" = "1-5 years", "5-10" = "5-10 years",
                      "10+" = "More than 10 years", born = "Born here"),
  age_group       = c("18-24" = "18-24", "25-34" = "25-34", "35-44" = "35-44", "45-54" = "45-54",
                      "55-64" = "55-64", "65+" = "65+"),
  gender          = c(female = "Female", male = "Male", "non-binary" = "Non-binary", "prefer-not" = "Prefer not to say"),
  language        = c(en = "English", mt = "Maltese", de = "German"))

tab_q <- function(d, city, var, question, multi) {
  n_resp <- nrow(d); x <- d[[var]]; answered <- !is.na(x) & x != ""
  if (multi) {
    opts <- names(labels[[var]])
    out <- tibble(option_code = opts,
                  n = sapply(opts, function(o) sum(grepl(paste0("\\b", o, "\\b"), x[answered]))))
  } else {
    out <- tibble(option_code = as.character(x[answered])) %>% count(option_code)
    lv <- names(labels[[var]])
    if (!is.null(lv)) {
      out <- tibble(option_code = union(lv[lv %in% out$option_code | var != "language"], out$option_code)) %>%
        left_join(out, by = "option_code") %>% mutate(n = replace_na(n, 0L))
      if (var == "language") out <- out %>% filter(n > 0)
    } else out <- out %>% arrange(desc(n), option_code)
  }
  lab <- labels[[var]]
  out %>% mutate(city = city, question = question, variable = var,
                 answer = if (is.null(lab)) option_code else coalesce(unname(lab[option_code]), option_code),
                 n_answered = sum(answered), n_respondents = n_resp,
                 pct = round(100 * n / sum(answered), 1),
                 note = ifelse(multi, "Multiple answers: % of respondents who answered; can sum > 100", "")) %>%
    bind_rows(if (sum(!answered) > 0) tibble(city = city, question = question, variable = var,
                                              option_code = NA, answer = "No answer", n = sum(!answered),
                                              n_answered = sum(answered), n_respondents = n_resp,
                                              pct = NA_real_, note = "Not included in the % base") else NULL) %>%
    select(city, question, variable, option_code, answer, n, pct, n_answered, n_respondents, note)
}
t3 <- bind_rows(lapply(list(list(ms, "Malta"), list(ks, "Klagenfurt")), function(cd)
  bind_rows(lapply(seq_len(nrow(q)), function(i) tab_q(cd[[1]], cd[[2]], q$variable[i], q$question[i], q$multi[i])))))

# Options offered in only one city
opt_city <- t3 %>% filter(answer != "No answer", variable != "neighborhood") %>%
  group_by(variable, answer) %>% summarise(cities = paste(sort(unique(city)), collapse = ", "), .groups = "drop")
only_one <- opt_city %>% filter(!grepl(",", cities))
t3 <- t3 %>% left_join(only_one %>% transmute(variable, answer, only = paste("Option only in", cities)),
                       by = c("variable", "answer")) %>%
  mutate(note = trimws(paste(note, ifelse(is.na(only), "", only)))) %>% select(-only)
wcsv(t3, "table3_survey_closed_questions.csv")
cat("\n== Table 3 (first rows)\n"); print(as.data.frame(head(filter(t3, variable != "neighborhood"), 40)))

# ---- 4. Summary --------------------------------------------------------------------------------
f1 <- function(cty, def, m) { r <- filter(t1, city == cty, green_definition == def, walk_min == m)
  sprintf("%.1f%% (%s)", r$pct_of_routable, format(r$residents_within, big.mark = ",")) }
f2 <- function(cty, v = "headline") { r <- filter(t2, city == cty, grepl(v, indicator))
  sprintf("%s m² (IQR %s to %s)", format(r$median_m2_per_person, big.mark = ","),
          format(r$p25_m2_per_person, big.mark = ","), format(r$p75_m2_per_person, big.mark = ",")) }
f3 <- function(cty, var, ans) { r <- filter(t3, city == cty, variable == var, answer == ans); sprintf("%.0f%%", r$pct) }
nr <- t1 %>% filter(walk_min == 5, green_definition == "UA green >= 500 m2")
md <- c(
  "# WP6 deck, November 2026: green accessibility and survey (Malta, Klagenfurt)", "",
  sprintf("Run %s by `mcda/wp6_nov2026_numbers.R`. Population: Malta GHSL reallocated to NSO Census 2021 (%s residents); Klagenfurt census grid (%s residents). Surveys: Malta n = %d, Klagenfurt n = %d (former residents excluded).",
          format(Sys.Date()), format(nr$residents_total[nr$city == "Malta"], big.mark = ","),
          format(nr$residents_total[nr$city == "Klagenfurt"], big.mark = ","), nrow(ms), nrow(ks)), "",
  "Green: Urban Atlas 2021 green urban areas, forests and wetlands (14110, 14130, 31000, 40000), same classes in both cities. Walking times: own OSM network routing at 5 km/h. % of residents in routable cells.", "",
  "## 1. Residents within a walk of green", "",
  "| | Malta ≥ 500 m² | Malta ≥ 0.5 ha | Klagenfurt ≥ 500 m² | Klagenfurt ≥ 0.5 ha |", "|---|---|---|---|---|",
  sapply(c(5, 10, 15), function(m) sprintf("| %d min | %s | %s | %s | %s |", m,
         f1("Malta", "UA green >= 500 m2", m), f1("Malta", "UA green >= 0.5 ha", m),
         f1("Klagenfurt", "UA green >= 500 m2", m), f1("Klagenfurt", "UA green >= 0.5 ha", m))), "",
  sprintf("Residents in cells without a route (excluded from %%): Malta %s, Klagenfurt %s.",
          format(nr$residents_not_routable[nr$city == "Malta"], big.mark = ","),
          format(nr$residents_not_routable[nr$city == "Klagenfurt"], big.mark = ",")), "",
  "## 2. Green per person (E2SFCA, step 1 / 0.7 / 0.4 for 0-5 / 5-10 / 10-15 min)", "",
  sprintf("- Malta: median %s", f2("Malta")), sprintf("- Klagenfurt: median %s", f2("Klagenfurt")),
  sprintf("- 10 min cut (1 / 0.7): Malta %s; Klagenfurt %s", f2("Malta", "10 min cut"), f2("Klagenfurt", "10 min cut")), "",
  "## 3. Survey, closed questions (beyond the budget game)", "",
  sprintf("- Visit green daily: Malta %s, Klagenfurt %s; never: Malta %s, Klagenfurt %s.",
          f3("Malta", "visit_frequency", "Daily (5-7 times a week)"), f3("Klagenfurt", "visit_frequency", "Daily (5-7 times a week)"),
          f3("Malta", "visit_frequency", "Never"), f3("Klagenfurt", "visit_frequency", "Never")),
  sprintf("- Green space within walking distance (yes): Malta %s, Klagenfurt %s.",
          f3("Malta", "green_nearby", "Yes"), f3("Klagenfurt", "green_nearby", "Yes")),
  sprintf("- Reasons (multiple): relaxation Malta %s / Klagenfurt %s; friends %s / %s; sport %s / %s.",
          f3("Malta", "visit_reasons", "Relaxation"), f3("Klagenfurt", "visit_reasons", "Relaxation"),
          f3("Malta", "visit_reasons", "Socialising with friends"), f3("Klagenfurt", "visit_reasons", "Socialising with friends"),
          f3("Malta", "visit_reasons", "Sport"), f3("Klagenfurt", "visit_reasons", "Sport")),
  "- Same closed questions in both cities. Options offered in one city only: language (Maltese / German) and, in Klagenfurt, residency \"Left 2+ years ago\" (2 respondents, excluded here). Neighbourhood lists are city specific.",
  "- No barriers question exists in either export.",
  "- Question wording is taken from the survey notebooks, not the verbatim questionnaire.", "",
  "Files: `table1_residents_within_walk_of_green.csv`, `table2_green_per_person.csv`, `table3_survey_closed_questions.csv`.")
writeLines(md, file.path(OUT, "summary.md"))
cat("\nWritten to", OUT, "\n"); print(list.files(OUT))
