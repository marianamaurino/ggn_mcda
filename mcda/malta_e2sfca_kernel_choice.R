# Kernel choice for mcda/malta_e2sfca_newpop.R: E2SFCA with ATGreen population and own routing under
# 10 distance decay kernels, compared with ATGreen values. Needs travel_times_min.rds from that script.
suppressMessages({library(dplyr); library(arrow); library(sf)})
tt <- readRDS(here::here("data/malta/accessibility_malta/own_routing/travel_times_min.rds"))
cv <- readr::read_csv(here::here("data/malta/accessibility_malta/own_routing/e2sfca_own_routing_cells.csv"), show_col_types = FALSE, col_types = readr::cols(gid = "c"))
g <- read_parquet(here::here("accessibility_schifanella/exposure/intermediate/green/green_urban_atlas.parquet")); S <- g$green_ha * 1e4
cT <- tt$cell_T; P <- cv$pop_atg; ur <- cv$assignment_status == "unroutable"
e2 <- function(W) { Wm <- W(cT); Wm[is.na(Wm)] <- 0; D <- colSums(Wm * P); R <- ifelse(D > 0, S / D, 0); o <- as.numeric(Wm %*% R); o[ur] <- NA; o }
K <- list(
  dai_d15 = function(t) ifelse(t <= 15, (exp(-0.5*(t/15)^2) - exp(-0.5))/(1 - exp(-0.5)), 0),
  dai_d10 = function(t) ifelse(t <= 10, (exp(-0.5*(t/10)^2) - exp(-0.5))/(1 - exp(-0.5)), 0),
  dai_d5  = function(t) ifelse(t <= 5,  (exp(-0.5*(t/5)^2)  - exp(-0.5))/(1 - exp(-0.5)), 0),
  gauss_s5_cut15  = function(t) ifelse(t <= 15, exp(-t^2/(2*5^2)), 0),
  gauss_s7.5_cut15= function(t) ifelse(t <= 15, exp(-t^2/(2*7.5^2)), 0),
  gauss_s10_cut15 = function(t) ifelse(t <= 15, exp(-t^2/(2*10^2)), 0),
  gauss_s15_cut15 = function(t) ifelse(t <= 15, exp(-t^2/(2*15^2)), 0),
  gauss_s5_nocut  = function(t) exp(-t^2/(2*5^2)),
  step_1_.7_.4    = function(t) ifelse(t <= 5, 1, ifelse(t <= 10, .7, ifelse(t <= 15, .4, 0))),
  step_5min_only  = function(t) ifelse(t <= 5, 1, 0))
res <- bind_rows(lapply(names(K), function(k) { x <- e2(K[[k]]); ok <- is.finite(x) & is.finite(cv$atg_gauss)
  tibble(kernel = k, sp_vs_atg_gauss = cor(x[ok], cv$atg_gauss[ok], method = "spearman"), pe_log_gauss = cor(log1p(x[ok]), log1p(cv$atg_gauss[ok])),
         sp_vs_atg_step = cor(x[ok], cv$atg_step[ok], method = "spearman"), pe_log_step = cor(log1p(x[ok]), log1p(cv$atg_step[ok])),
         median = median(x[ok]), p98 = quantile(x[ok], .98)) }))
res <- res %>% mutate(across(where(is.double), ~ round(., 3))); print(as.data.frame(res))
readr::write_csv(res, here::here("output/figures_mcda/atgreen_checks/e2sfca_kernel_choice.csv"))
cat("ATGreen gauss median", median(cv$atg_gauss, na.rm=T), "p98", quantile(cv$atg_gauss, .98, na.rm=T), "| step median", median(cv$atg_step, na.rm=T), "p98", quantile(cv$atg_step,.98,na.rm=T), "\n")
