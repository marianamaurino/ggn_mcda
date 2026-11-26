# mcda/: file index

What each file in this folder is for. Methods and decisions: `MCDA_paper_results_spec.md` (master spec)
and `CHANGELOG.md` (dated history). Data and outputs are not in git (see the root `CLAUDE.md`).

## Main pipeline

Run order: input builders, then the two scoring notebooks, then the paper tables and figures.

| File | Role |
|---|---|
| `Rebuild_malta_master_full_khomenko.Rmd` | Malta input grid with reallocated population |
| `klagenfurt_dedup_inputs.R` | Removes duplicated Klagenfurt grid cells at the source (2026-11-19) |
| `walk_filter.R` | Pedestrian filter for the OSM walking network (both cities) |
| `malta_e2sfca_newpop.R`, `klagenfurt_e2sfca_newpop.R` | Own routing: walking time to green and E2SFCA green per person |
| `street_greenery_canopy_malta.Rmd` | Malta street canopy indicator (`street_greenery_canopy_cells.csv`) |
| `traffic_road_type.Rmd`, `traffic_road_type_k3.R` | Traffic: OSM road type classes (K3 main; K2, K5 sensitivity) |
| `ua_constraint.R` | Not eligible cells: airport, port, water (majority class rule) |
| `klagenfurt_ua2018_cells.R` | Klagenfurt Urban Atlas 2018 area per class and cell, for the water constraint |
| `Malta_MCDA_260702_realloc.Rmd` | Malta scoring: `malta_mcda_processed_realloc.rds`, `malta_sensitivity.rds` |
| `Klagenfurt_MCDA_260520.Rmd` | Klagenfurt scoring: `klagenfurt_mcda_priority_may.rds`, `klag_sensitivity.rds` |
| `Tables_MCDA.Rmd` | Paper Tables 1, 2, S5, S6 |
| `Figures_MCDA.Rmd`, `criteria_maps_paper.R` | Paper figures, priority maps and per criterion maps |

Survey: `Malta_survey_results.Rmd`, `Klagenfurt_survey_results.Rmd` and the two `*_survey_report.qmd`.

## Sensitivity analyses (feed Table S6 or the supplement)

| File | Role |
|---|---|
| `survey_allocation_style.Rmd` | Budget allocation style; median instead of mean weights (Table S6 row) |
| `Burden_coincidence_random_weights.Rmd` | Burden coincidence, random (Dirichlet) weights, citizen vs equal weights |
| `traffic_cams_reg_check.Rmd` | Traffic indicator validation; CAMS-REG vehicle km variant |
| `malta_e2sfca_kernel_choice.R` | E2SFCA distance decay kernel choice |
| `Malta_green_pp_log_test.Rmd` | Green per person: log vs min max |
| `green_class_32000_test.R` | Class 32000 (herbaceous vegetation) in the green definition |
| `malta_mcda_missing.R` | Missing values per indicator, available weight rule |

## Exploratory checks and effect reports (not inputs to anything)

| File | Role |
|---|---|
| `canopy_switch_effects.R`, `canopy_switch_maps.R` | Effect of the switch to street canopy (2026-11-23) |
| `traffic_k3_switch_effects.R` | Effect of the switch to road type K3 (2026-11-24) |
| `walk_time_switch_effects.R` | Effect of the switch to own walking routing (2026-11-20) |
| `water_constraint_effects.R`, `majority_rule_effects.R` | Effect of the water constraint and majority class rule (2026-11-25) |
| `score_change_2026_11_19.R` | Score change report, 19 November 2026 |
| `checks_industrial_streetview.Rmd` | Industrial cells and street view checks |
| `malta_atgreen_checks.R`, `klagenfurt_gap_points.R` | Own routing vs ATGreen checks |
| `herbaceous_map_malta.R` | Map of class 32000 in Malta |
| `Correlations_standarization.Rmd` | Early correlations and normalisation, precursor of the Malta scoring |
| `poster_UT2026_numbers.R`, `klagenfurt_layers_export.R` | UT2026 poster numbers and layer diagram (frozen, tag `ut2026-poster`) |
| `wp6_nov2026_numbers.R` | WP6 deck numbers, November 2026 |

## Instructions (record of decisions)

`instructions/` (dated task instructions, saved verbatim), `*_instructions.Rmd`,
`instructions_download_treecanopy.Rmd`, `mcda_criteria_maps_2026_11_17.md`.
