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
- `Malta_MCDA_260702_realloc.Rmd`: writes `data/malta/malta_mcda_processed_realloc.rds` (`priority_citizen`)
- `Klagenfurt_MCDA_260520.Rmd`: writes `data/klagenfurt/klagenfurt_mcda_priority_may.rds`

Survey
- `Malta_survey_results.Rmd`, `Malta_survey_report.qmd`
- `Klagenfurt_survey_results.Rmd`, `Klagenfurt_survey_report.qmd`

Paper
- `Figures_MCDA.Rmd`: Figures 3 and 4, to `data/malta/outputs/`
- `Tables_MCDA.Rmd`: Tables 1, 2, S5, S6 and `data/malta/outputs/contribution_table.rds`

Exploratory
- `Correlations_standarization.Rmd`: correlations and normalisation, precursor of the Malta MCDA

## Inputs from elsewhere

- `analysis/malta_build_master.Rmd` builds `data/malta/malta_master_full.rds` (shared with the population chain)
- `analysis/Rebuild_malta_master_full_khomenko.Rmd` builds `malta_master_full_reallocated_khomenko.rds`
- `analysis/exposure/` (E2SFCA accessibility, `final_metrics.parquet`)

The MCDA × scenario notebooks stay in `analysis/` with the HIA: `05_mcda_overlap_malta.Rmd`,
`Scenario_MCDA_overlap_klagenfurt.Rmd`, `MCDA_scenarios_targeted_klagenfurt.Rmd`.
