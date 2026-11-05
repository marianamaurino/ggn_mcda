# MCDA changelog

## 2026-11-05: available weight rule (≥ 80% of weight), Malta and Klagenfurt, for the UT2026 poster

Git tag: `ut2026-poster`.

**What changed in the scoring** (`Malta_MCDA_260702_realloc.Rmd`, `Klagenfurt_MCDA_260520.Rmd`, chunk `compute-wlc`)
- **Available weight rule:** a cell is scored if its available criteria carry ≥ 80% of the total citizen weight. Its score is the weighted mean over those criteria, Σ(wᵢ·sᵢ) / Σwᵢ. Before, a cell missing any criterion got no score.
- **Equal weights and sensitivity analyses:** the equal-weights score and every sensitivity variant (±20% perturbation, without traffic, log traffic, step E2SFCA, raw income) use the same rule on the same cells.
- **Missing values stay missing:**
  - Malta green per person (`norm_green_exp`): before, NA was set to 0, the lowest priority contribution.
  - Klagenfurt walking time (`norm_green_time`): before, NA fell through `case_when` and scored 1.00, the highest priority.
- **Malta, not eligible for greening:** cells whose majority Urban Atlas 2021 class is airport (12400, 358 cells) or port (12300, 101 cells) get no score (new chunk `eligibility-mask`). Under the rule, 10 airport cells and 1 port cell newly entered the top quintile; 68 airport and 66 port cells were already in it.

**Other notebook changes**
- **Klagenfurt sample size:** `KEEP_FORMER_RESIDENTS <- TRUE` keeps the 2 former residents, so the weights stay those of the saved map and Figure 4 (n = 184). Set it to `FALSE` for n = 182.
- **Klagenfurt survey encoding:** 2 neighbourhood answers in the survey export are Latin-1. They are re-encoded after reading; without this the knit fails ("invalid string in PangoCairo_Text").
- **Prose:** the Klagenfurt notebook text still says income is excluded, but the code and the saved score include it (7 criteria). The text was not changed.

**Effect**

| | Malta old → new | Klagenfurt old → new |
|---|---|---|
| Cells scored / no score | 10,214 / 443 → 10,194 / 463 | 12,329 / 422 → 12,329 / 422 |
| Incomplete cells now scored | 245 | 208 (walking time missing) |
| Cells removed | 265 (airport and port) | 0 |
| Spearman r, common cells | 1.000 | 0.994 |
| Old top quintile retained (common cells) | 100% | 97.9% |
| Cells changing quintile | 4.8% | 3.5% |

On cells complete in both versions the scores are identical (max difference < 1e-15); the weights are unchanged. Old vs new poster numbers are in `output/figures_mcda/poster/` and `output/figures_mcda/poster_pre_avail80/`; the latter is `MCDA_VARIANT=pre_avail80 Rscript mcda/poster_UT2026_numbers.R`.

**Backups.** The HIA results were built from the score saved before this change, kept as:
- `data/malta/malta_mcda_processed_realloc_pre_avail80.rds` (md5 `2c262ca473464e040c48160062232476`)
- `data/klagenfurt/klagenfurt_mcda_priority_may_pre_avail80.rds` (md5 `41b210173bc7c812cbc0b8c21ba90b25`)
- Figures as they were before: `output/figures_mcda/_pre_avail80/`

**The HIA was not re-run.** `HIA_malta_main.Rmd` (`MCDA_RDS`, line ~153), `HIA_klagenfurt.Rmd`, `05_mcda_overlap_malta.Rmd` and `Scenario_MCDA_overlap_klagenfurt.Rmd` read the main file names. If they are re-knitted as they are, they will pick up the new score. To reproduce the current HIA results, point them to the `_pre_avail80` files.

**New files at this state** (data and outputs live in `../ggn_analysis_archive`, not in git)
- `data/malta/malta_mcda_processed_realloc.rds`, md5 `bfd0baaaaa1645508a7a5688b90cc78b`
- `data/klagenfurt/klagenfurt_mcda_priority_may.rds`, md5 `2be9381c52ec2440a251e8529cfff4b3`
- `data/malta/Population_Malta_reallocated_nso.gpkg` (input), md5 `e09c5fa68091f870646ea38c3381c238`
- `data/malta/malta_grid_ua2021_majority_class.csv`: Urban Atlas 2021 majority class per cell (check only)
- Figures: `output/figures_mcda/` (Figures 3 and 4 Lancet, priority maps, palette trials `warm_red` and `teal_red`, criterion maps), `data/malta/outputs/Figure3_Malta.*`, `Figure4_Klagenfurt.*`
- Poster numbers and panel A figures: `output/figures_mcda/poster/`

**Related checks, same day**
- `mcda/malta_mcda_missing.R` → `output/figures_mcda/missing_values/`: missing values per indicator, variants, the 80% rule.
- `mcda/malta_atgreen_checks.R` → `output/figures_mcda/atgreen_checks/`: ATGreen vs the study grid.
- `mcda/malta_e2sfca_newpop.R`: E2SFCA rebuilt with the new population, kept as a sensitivity analysis; the MCDA was not switched to it.
- `mcda/poster_UT2026_numbers.R`: the poster numbers. Malta residents now come from the new population grid; the ±20% perturbation uses the available weight rule.
