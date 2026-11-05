# mcda/: MCDA scoring, citizen survey, MCDA paper figures and tables

Moved here from `analysis/` on 2026-11-04 with `git mv` (history kept, file names unchanged).

## Rules

- Paths: `here::here("data/...")`, relative to the project root. No absolute paths, no `../`.
- The MCDA never reads anything from the HIA (`analysis/HIA_*`, `output/scenario_results/`). The HIA
  reads the saved MCDA outputs below.
- Do not re-run the scoring notebooks; their saved outputs are canonical (root `CLAUDE.md`,
  "MCDA results"). For Malta the reallocated population version is always the canonical one.
- `Tables_MCDA.Rmd` writes its HTML tables next to the notebook (`mcda/Table*.html`).

## Files

Scoring (outputs used by the HIA)
- Since 2026-11-05 both notebooks use the available weight rule (score if >= 80% of weight available;
  Malta airport/port not eligible), see `CHANGELOG.md`. The HIA results were built from the
  `*_pre_avail80.rds` backups; the HIA was not re-run (tag `ut2026-poster`).
- `Malta_MCDA_260702_realloc.Rmd`: writes `data/malta/malta_mcda_processed_realloc.rds` (`priority_citizen`)
- `Klagenfurt_MCDA_260520.Rmd`: writes `data/klagenfurt/klagenfurt_mcda_priority_may.rds`

Survey
- `Malta_survey_results.Rmd`, `Malta_survey_report.qmd`
- `Klagenfurt_survey_results.Rmd`, `Klagenfurt_survey_report.qmd`

Paper
- `Figures_MCDA.Rmd`: Figures 3 and 4, to `data/malta/outputs/`; Lancet style versions and the two city priority maps to `output/figures_mcda/`
- `Tables_MCDA.Rmd`: Tables 1, 2, S5, S6 and `data/malta/outputs/contribution_table.rds`

Input builder
- `Rebuild_malta_master_full_khomenko.Rmd`: writes `data/malta/malta_master_full_reallocated_khomenko.rds`
  (reallocated population), the grid the Malta MCDA scores (moved from `analysis/` 2026-11-04)

Accessibility inputs (links to `../ggn_analysis_archive/analysis/`, not in git; moved from `analysis/` 2026-11-04)
- `exposure/` and `accessibility/`: E2SFCA outputs (`final_metrics.parquet`). The two folders hold different
  versions; `Malta_MCDA_260702_realloc.Rmd` reads `accessibility/` (line ~82) and `exposure/` (line ~348),
  `Correlations_standarization.Rmd` reads `exposure/`. Klagenfurt reads `output/accessibility/`.

Exploratory
- `Correlations_standarization.Rmd`: correlations and normalisation, precursor of the Malta MCDA

## Inputs from elsewhere

- `analysis/malta_build_master.Rmd` builds `data/malta/malta_master_full.rds` (shared with the population chain)

The MCDA × scenario notebooks stay in `analysis/` with the HIA: `05_mcda_overlap_malta.Rmd`,
`Scenario_MCDA_overlap_klagenfurt.Rmd`, `MCDA_scenarios_targeted_klagenfurt.Rmd`.
