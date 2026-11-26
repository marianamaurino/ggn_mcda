# MCDA changelog

## 2026-11-06: green per person with the new population; new survey exports

**Malta green per person (`norm_green_exp`).** The main input is now our E2SFCA rebuild with the new
population (`mcda/malta_e2sfca_newpop.R`, output `data/malta/accessibility_malta/own_routing/norm_green_exp_newpop.csv`):
NSO-rescaled GHSL population, OSM walking network, igraph routing at 5 km/h, ATGreen's 106 UA2021 patches and
origin points, Gaussian kernel exp(-t²/2σ²) with σ = 5 min, cut at 15 min; the step 1/0.7/0.4 sensitivity uses the same rebuild.
ATGreen's own values (GHSL population, Valhalla) are kept as a sensitivity (`*_atg` columns, `priority_atg_exp`);
that sensitivity reproduces the previous score exactly. Column names of the main inputs are unchanged.

**Malta `Total_Population`** on the MCDA grid is now the NSO grid (`pop_reallocated_nso`, 346,005); the old
DHIR/Khomenko values are kept as `Total_Population_dhir_khomenko`. It enters no criterion.

**Surveys.** Exports are now .xlsx and the .csv files were removed: `data/malta/maltasurvey_jun26.xlsx`
(123 responses, same answers as before) and `data/klagenfurt/klagenfurtsurvey_nov26.xlsx` (186, +2, last
2026-10-17). All readers use `R/read_survey.R` (first sheet; maps Excel date serials back to "1-5", "5-10",
"2-4", "5-7"). Klagenfurt keeps the 2 former residents (`KEEP_FORMER_RESIDENTS <- TRUE`, n = 186).

**Effect**

| | Malta | Klagenfurt |
|---|---|---|
| Spearman r vs 2026-11-05 score | 0.995 | 1.000 |
| Cells changing quintile | 4.9% | 0.5% |
| Old top quintile retained | 97.6% | 99.9% |
| Cells scored | 10,194 (unchanged) | 12,329 (unchanged) |

Re-knitted: both scoring notebooks, both survey notebooks and reports, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`,
`poster_UT2026_numbers.R`. The HIA was not re-run (still on `*_pre_avail80`).

**Backups of the 2026-11-05 state (tag `ut2026-poster`):** `data/malta/malta_mcda_processed_realloc_ut2026_poster.rds`,
`data/klagenfurt/klagenfurt_mcda_priority_may_ut2026_poster.rds`, `output/figures_mcda/_ut2026_poster/`,
`data/malta/outputs/_ut2026_poster/`.

**Prose not updated (TODO markers):** status note at the top of the Malta MCDA notebook; Klagenfurt survey
report "until September 2026"; `output/figures_mcda/poster/poster_numbers_report.md` (handwritten, says n = 184).

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

## 2026-11-17: Klagenfurt survey re-export, former residents excluded again

- New export `data/klagenfurt/klagenfurtsurvey_nov26.xlsx` (saved 2026-11-17): 186 rows, budget answers identical to the 2026-11-06 export.
- `Klagenfurt_MCDA_260520.Rmd`: `KEEP_FORMER_RESIDENTS <- FALSE`, the 2 "left-2-plus" respondents are excluded again (n = 184). Keeping them was for the UT2026 poster only.
- `Figures_MCDA.Rmd`: the Klagenfurt survey now excludes "left-2-plus" too, so Figure 4 and `klag_survey_summary.rds` match the MCDA weights (n = 184).
- Weights (n = 184): too-hot streets 25.5%, green out of reach 11.3%, low income 14.3%, traffic 18.0%, air quality 16.1%, nature/water 14.7%.
- Score vs previous (`data/klagenfurt/klagenfurt_mcda_priority_may_pre_nov17.rds`, md5 `af2c76489e9ec716d4c5d72c6b239eee`): same 12,329 cells scored, Spearman 1.000, max abs difference 0.0012, 36 cells (0.3%) change quartile, 99.8% of Q4 stays in Q4.
- New `data/klagenfurt/klagenfurt_mcda_priority_may.rds`, md5 `181cce3a1831e81ec7e9e25d1d9b1c00`.
- Re-knitted: `Klagenfurt_MCDA_260520.Rmd`, `Klagenfurt_survey_results.Rmd`, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`. HIA not re-run.

## 2026-11-19: Klagenfurt duplicate cells removed at source; walking time continuous; street greenery cap from data

Spec: `mcda/MCDA_paper_results_spec.md` (1.1, 3.3, 3.4, 8.1 to 8.3, updated 19 November). **The MCDA notebooks were edited but not re-knitted**; the saved score files are unchanged.

**Klagenfurt duplicates (origin and fix).** `sandbox/Plot_klagenfurt.Rmd` (archive, March 2026), the last writer of `klagenfurt_master_full.rds`, left joined `klagenfurt_recreation_areas.csv` (one row per cell × category) by gid: 101 cells repeated 2 or 3 times (12,525 rows). `klagenfurt_grid_100m_income.geojson` (built outside the repo from that grid) carries the same repeats; the MCDA join by ID multiplied them to 4 or 9 (12,751 rows, 12,418 cells).
- `mcda/klagenfurt_dedup_inputs.R`: one row per cell in both files; `recreation_m2` = sum over categories per cell, beaches dropped (Malta rule; not a Klagenfurt criterion). Backups `*_pre_dedup` (master md5 `9b9f7854f7003c3cb0d23418335c71ad`, income md5 `36b0f6dee3656ba98718f0b1293c30bf`). New master md5 `02ee1cc5458cba29d581c6e2c45aacf0`, income md5 `27bd6eb6b362f4cd18888f93c7c48687`.
- `Klagenfurt_MCDA_260520.Rmd`: `stopifnot` one row per cell after the income join.
- Statistics computed over the 12,751 rows so far: in `Klagenfurt_MCDA_260520.Rmd` the p2/p98 caps of every indicator, the descriptive table, the Spearman correlation matrix, `class_citizen`, the scored count (12,329 rows = 11,996 cells) and the sensitivity comparisons; quintiles in `Figures_MCDA.Rmd` (Figure 4, priority maps), `Tables_MCDA.Rmd` (Table 2 top quintile, class agreement table), `poster_UT2026_numbers.R`, `analysis/Scenario_MCDA_overlap_klagenfurt.Rmd` (quartile breaks). Already deduplicated: `HIA_klagenfurt.Rmd`, `MCDA_scenarios_targeted_klagenfurt.Rmd`, `klagenfurt_layers_export.R`, `wp6_nov2026_numbers.R`, `klagenfurt_e2sfca_newpop.R`.

**Method changes (notebooks edited, not re-run)**
- Klagenfurt walking time to green: continuous min-max capped at p98 (14.9 min), as Malta; was 4 classes.
- Malta street greenery: cap = p98 of the data (11.70%); was hardcoded 14.18%.
- Malta green per person: the score keeps our E2SFCA rebuild (NSO population); ATGreen stays a sensitivity analysis (spec 3.3, decided 19 November).

**Effect on the scores** (`mcda/score_change_2026_11_19.R`, recomputed from the saved files, weights recovered exactly; Spearman over cells scored in both; top quintile of the current version as currently computed)

| Change | Scored cells | Spearman | Top quintile retained | Cells changing quintile |
|---|---|---|---|---|
| Klagenfurt, cells deduplicated only | 11,996 | 1.000 | 100.0% | 1.8% |
| Klagenfurt, + walking time continuous | 11,996 | 0.994 | 96.6% | 11.3% |
| Malta, street greenery cap 11.70% | 10,194 | 0.999 | 99.3% | 1.8% |

**Criterion maps for the paper**: `mcda/criteria_maps_paper.R` → `output/figures_mcda/criterion_maps_paper/` (`Figure_criteria_Malta`, `Figure_criteria_Klagenfurt`, `FigureS_Klagenfurt_NO2_PM25`; PDF, SVG, PNG, PPTX; `panels/` one PNG per panel). Raster drawing, Source Sans 3 (as the HIA figures, Arial not installed), shared limits for LST, NO2, blue space, traffic and walking time.

**Re-knitted 2026-11-19** (in order): `Malta_MCDA_260702_realloc.Rmd`, `Klagenfurt_MCDA_260520.Rmd`, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`. Saved scores match the table above exactly.
- Previous scores kept as `data/malta/malta_mcda_processed_realloc_pre_nov19.rds` (md5 `7df4bad8bacd71ee0f5c8c2c0ea6cc6b`) and `data/klagenfurt/klagenfurt_mcda_priority_may_pre_nov19.rds` (md5 `181cce3a1831e81ec7e9e25d1d9b1c00`).
- New: `malta_mcda_processed_realloc.rds` md5 `67dab27d2f587e3da2492feac7416d13` (10,194 cells scored); `klagenfurt_mcda_priority_may.rds` md5 `49d515ac28de63d69c41d0333d501788` (12,418 rows = cells, 11,996 scored).
- Table 2 top quintile cells: Malta 2,038, Klagenfurt 2,399.
- Criterion maps: land surface temperature on its own scale per city (Malta 28.7 to 50.7 °C, Klagenfurt 17.1 to 39.9 °C), spec 8.3 updated.
- HIA not re-run: `HIA_malta_main.Rmd` and the Klagenfurt HIA notebooks read the main file names, so a re-knit would now pick up the new scores.

## 2026-11-19 (later): Malta green per person on a log scale, missing in unpopulated cells

Tests: `mcda/Malta_green_pp_log_test.Rmd` (sections 1 to 7). Spec 3.3 and 3.4 updated.

**Why.** The raw indicator is extremely skewed (skewness 16.9) and capped at p98 = 166.5 m², a value set by
unpopulated cells (populated p98 25.8 m²): 93.7% of cells normalised above 0.9, so the criterion carried an
effective weight of 6.3% against a citizen weight of 9.4%. A log version without changes in unpopulated cells
moved 271 rural and urban unpopulated cells with zero green per person into the top quintile (65% of entering
cells); green per person is undefined where nobody lives.

**What changed** (`Malta_MCDA_260702_realloc.Rmd`, chunk `normalization`, function `norm_gpp_log`)
- `norm_green_exp` = 1 − min max of log10(m² per person), no offset; bounds = p2 and p98 of the log over
  eligible populated cells (0.0213 and 29.3 m² per person); zero green per person = 1; missing in unpopulated
  cells (`Total_Population` = `pop_reallocated_nso` = 0) and in unrouted cells. Unpopulated cells are scored on
  the other criteria (90.6% of the weight) under the available weight rule; the scored set is unchanged (10,194).
- The ATGreen and step sensitivity variants use the same normalisation.
- New sensitivity (spec 3.3): the previous version (raw, min max capped at p98 over all cells) as
  `norm_green_exp_minmax` / `priority_gpp_minmax`.
- The `eligibility-mask` chunk moved before `normalization` (needed for the bounds); its code is unchanged.
- Spec 3.3: in Malta only green urban areas (14110, 14130: 106 patches, 114 ha) are present; the green
  definition itself is unchanged. Walking time to green (`mcda/accessibility/final_metrics.parquet`) is identical,
  cell for cell, to ATGreen's "nearest" run, whose configuration uses the same Urban Atlas classes and 500 m²
  minimum, so both criteria rest on the same patches.

**Effect** (main vs previous score, eligible cells): Spearman 0.964; top quintile retained 89.4%; 22.3% of cells
change quintile; effective weight of green per person 10.2% (was 6.3%; citizen 9.4%). Entering the top quintile:
193 populated cells, 10 unpopulated urban, 13 unpopulated rural.

**Re-knitted:** `Malta_MCDA_260702_realloc.Rmd`, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`, `criteria_maps_paper.R`
(green per person panel on a log10 scale with the score's bounds, unpopulated cells grey). Previous score kept as
`data/malta/malta_mcda_processed_realloc_pre_gpp_log.rds` (md5 `67dab27d2f587e3da2492feac7416d13`); new
`malta_mcda_processed_realloc.rds` md5 `a7c09837850c97ab94383d176f400157`. HIA not re-run.

**Prose not updated (TODO marker):** normalisation section of the Malta notebook (says min max for all).
`mcda/Malta_green_pp_log_test.Rmd` now reads the `_pre_gpp_log` backup, so "current" stays the previous version.

**Green source rationale (text updated 2026-11-19).** The Malta notebook paragraph "Choice: OSM / confluent
population" (section 2.4, Metric selection) was out of date: the score has used Urban Atlas green urban areas since
the E2SFCA was adopted. Rewritten as "Choice: Urban Atlas 2021 green urban areas, not OSM": OSM overestimates
(field checks: abandoned land with sparse vegetation, too small, or private; values too high compared with the
literature). Numbers in the paragraph are now inline R. Spec 3.3 gives the same rationale. Reference still to add
(TODO in the notebook).

## 2026-11-20: walking time from our own routing (both cities); pedestrian filter fix; zero rule; eligible cap

**Walking time (`norm_green_time`), both cities.** The main input is now our own OSM routing
(`mcda/malta_e2sfca_newpop.R`, `mcda/klagenfurt_e2sfca_newpop.R`, columns `own_nearest_sec` / `own_nearest_min`),
using green classes 14110, 14130, 31000 and 40000 (no 32000). ATGreen's walking time (Valhalla in Malta,
OSRM in Klagenfurt, including 32000) is kept as a sensitivity (`nearest_green_min_atg`, `norm_green_time_atg`,
`priority_atg_walk`).

**Pedestrian filter (`mcda/walk_filter.R`, shared by both routing scripts).** The old filter dropped every
`highway=cycleway`. Cycleways with `foot=yes/designated/permissive` are now kept; ways with `foot=no` or
`access=private` are always dropped; `access=no` is dropped unless foot access is explicit; ways with no
highway tag are dropped. Kept: Malta 29,441 of 30,450 ways (before 29,391; cycleways 75 of 95, before 0), Klagenfurt 26,228 of
27,294 (before 25,816; cycleways 513 of 625). `access=military` also dropped (second run, 37 Klagenfurt ways, none in Malta). Tables: `data/<city>/accessibility_<city>/own_routing/<city>_filter_by_highway.csv`
and `_filter_by_foot_access.csv`. In Klagenfurt the fix closes all 208 origin points where our time exceeded ATGreen's by >= 3 min: 188 through
shared foot and cycle paths, the other 20 because they sat on `highway=track` + `access=no` ways (kept before,
excluded by OSRM). No origin point is now >= 3 min longer than OSRM (max +2.9 min); 169 are >= 3 min shorter
(`mcda/klagenfurt_gap_points.R`, map `klagenfurt_gap_points/former_gap_points_access_no_tracks.png`).

**Zero rule (as ATGreen).** An origin point inside a green patch has time 0 to that patch, and a connector
cell assigned to such a point gets 0 (no connector walk). Applied to walking time in both cities and to the
E2SFCA travel times (Malta green per person). Origin points inside green: Malta 563, Klagenfurt 3,811.

**Cap.** Malta walking time p98 now over eligible cells (33.86 min; all cells 34.00). Klagenfurt: all cells
eligible, no change.

**Effect on the score, step by step** (`output/figures_mcda/walk_time_switch_2026_11_20/score_effect_by_step.csv`)

| City | Step | Spearman vs previous | Cells changing quintile vs previous |
|---|---|---|---|
| Malta | Switch walking time to our routing | 0.999 | 2.2% |
| Malta | Filter fix (walking time and green per person) | 1.000 | 0.3% |
| Malta | Zero rule | 1.000 | 0.0% |
| Malta | Eligible cells cap | 1.000 | 0.2% |
| Klagenfurt | Switch to our routing (incl. 32000) | 0.996 | 5.8% |
| Klagenfurt | Drop 32000 | 1.000 | 0.6% |
| Klagenfurt | Filter fix | 0.999 | 1.5% |
| Klagenfurt | Zero rule | 1.000 | 2.0% |
| Klagenfurt | Eligible cells cap | 1.000 | 0.0% |

Overall vs the 2026-11-19 score: Malta Spearman 0.999, 2.2% of cells change quintile, 99.1% of the top quintile
retained; Klagenfurt 0.996, 4.5%, 98.4% (second run, military dropped). Maps: `quintile_change_map_<city>.png` in the same folder.
Knitted `priority_citizen` equals the expected scores from the effects script (max difference < 1e-15).

**Sensitivities in the notebooks.** ATGreen walking time: Malta Spearman 0.999 (2.2% change quintile, 99.2%
of top quintile retained); Klagenfurt 0.996 (4.5%, 98.4%). Malta without green per person (log version, nine
criteria, weights rescaled): Spearman 0.974, 18.2% change quintile, 89.8% of top quintile retained.
Walking speed 4 km/h (times x 5/4; walking time normalisation is scale invariant, so only green per person
changes): Malta Spearman 0.996, 5.9% change quintile, 95.3% of top quintile retained (green per person 4 vs
5 km/h Spearman 0.914); Klagenfurt identical score (Spearman 1.000).

**WHO 9 m² per person** references removed from the Malta notebook, `MCDA_paper_results_spec.md`,
`docs/mcda_methods_changes_2026-11-06.md`, `green_class_32000_test.R` and `malta_indicators.csv`.

**Backups of the 2026-11-19 state:** `data/malta/malta_mcda_processed_realloc_pre_nov20.rds`
(md5 a7c09837850c97ab94383d176f400157), `data/klagenfurt/klagenfurt_mcda_priority_may_pre_nov20.rds`
(md5 49d515ac28de63d69c41d0333d501788), own routing outputs `*_pre_nov20` in both `own_routing/` folders.
`green_class_32000_test.R` and `wp6_nov2026_numbers.R` now read the `*_pre_nov20` routing files.

Re-knitted: both scoring notebooks, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`, `criteria_maps_paper.R`. The HIA was
not re-run.

**Also:** Malta notebook text on the step E2SFCA (UA2018, weights 1.0 / 0.68 / 0.22) corrected to UA2021 and
1 / 0.7 / 0.4. Spec 1.1 updated (Klagenfurt duplicates removed at source on 2026-11-19; join and count by `ID`;
`gid` is missing in 422 unscored cells). `walk_time_switch_effects.R` reads the `*_pre_nov20` scores as baseline.

**Open:** `malta_sensitivity.rds` and `klag_sensitivity.rds`, read by `Tables_MCDA.Rmd`, are written by no notebook.

## 2026-11-20 (later): burden coincidence and random weights (A to D); leave one out; Table S6 inputs

**New notebook `mcda/Burden_coincidence_random_weights.Rmd`** (outputs `output/figures_mcda/burden_coincidence_2026_11_20/`),
on the current scores. Hypothesis: citizen weights change the map less where burdens coincide (Klagenfurt) than
where they are decoupled (Malta). Criterion level (Klagenfurt air quality = mean of NO2 and PM2.5, 6 criteria,
equal weight 1/6), scored cells of the main score, available weight rule, Spearman, seed 20261120.
- A: mean |Spearman| Malta 0.237, Klagenfurt 0.230; mean signed 0.031 vs 0.099; PC1 33.5% (chance 10%) vs 40.2%
  (16.7%); cells in the top quintile of >= 3 criteria vs permuted: Malta 22.9% vs 23.2% (ratio 0.99), Klagenfurt
  10.5% vs 7.4% (1.42). Malta street greenery cannot define a top quintile (90% of cells tied at maximum).
- B (1,000 Dirichlet draws vs equal weights): Spearman median Malta 0.772 (p5 to p95 0.565 to 0.897), Klagenfurt
  0.875 (0.593 to 0.954); top quintile overlap 63.1% vs 76.0%.
- C1 (five shared criteria): Malta 0.793, Klagenfurt 0.909. C2: map change per unit of weight distance
  (1 - Spearman / Euclidean distance, citizen vs equal) Malta 0.81, Klagenfurt 0.11; slope over draws 0.88 vs 0.50.
- D: robust core (> 90% of draws in top quintile) Malta 1.2% of cells (0.9% of residents), Klagenfurt 5.4% (16.8%).

**Leave one out** (both scoring notebooks, replaces the Malta "without green per person" check): each criterion
dropped, weights rescaled. Lowest Spearman: Malta without grey infrastructure 0.747 (57.8% of top quintile
retained); Klagenfurt without urban heat 0.906 (84.0%).

**Table S6 inputs.** The scoring notebooks now write `data/malta/malta_sensitivity.rds` and
`data/klagenfurt/klag_sensitivity.rds` (Spearman, top quintile retained, cells changing quintile; +/-20% recomputed
with Spearman). `Tables_MCDA.Rmd` reads the Klagenfurt file from `data/klagenfurt/`. Spec 5.3 updated.
Scores unchanged (re-knit checked against the expected scores).

**Flagged, not changed:** Klagenfurt `priority_equal` gives 1/7 per indicator (air quality 2/7), not 1/6 per
criterion (spec 2.3); the older +/-20% and "without traffic" sections of the Malta notebook report Pearson;
Table 1 of `Tables_MCDA.Rmd` is outdated (UA2018, "PRELIMINARY Euclidean proxy").

## 2026-11-23: Malta street greenery from street canopy (spec 3.6)

**What changed.** Malta street greenery (`norm_tree`) now reads `street_canopy_pct`: the share of a 10 m street
buffer (kept OSM classes, spec 3.6) covered by canopy of 3 m or more in the Meta and WRI canopy height map v2
(1 m; imagery 9 July 2019 and 18 January 2020). Built in `mcda/street_greenery_canopy_malta.Rmd`, read from
`data/malta/street_greenery_canopy_cells.csv` by `gid`. Normalisation: cost criterion, linear, 1 minus min max,
0 to the p98 over eligible cells with a street buffer (56.66%), capped. Cells with no street buffer: `norm_tree = 0`
(not applicable, spec 4.2), counted as available weight (3,007 eligible cells). `perc_tree` (Urban Atlas 2018
Street Tree Layer) stays in the score file for the sensitivity analysis (`norm_tree_stl`).

**Why.** `perc_tree` had about 90% of cells tied at zero (500 m² minimum mapping unit), so street greenery could not
rank cells and could not define a top quintile in the burden coincidence step. log10(x + 1) was tested and not adopted:
it moved the top quintile from populated urban streets with about 10% canopy to cells with 0% canopy (canopy
notebook, Steps 9 and 10).

**Sensitivity (spec 3.6, Table S6, new section "Street greenery variants" in the scoring notebook).** Spearman and
top quintile retained vs the main score: log10(x + 1) 0.978, 84.7%; agricultural and open land classes not applicable
0.865, 77.2%; 15 m buffer 0.984, 96.9%; canopy 2 m 0.999, 97.0%; canopy 5 m 0.996, 96.0%; whole cell canopy 0.805,
87.8%; no street as missing (option a) 0.997, 99.9%; Street Tree Layer 2018 (previous) 0.811, 82.7%. New columns:
`norm_tree_*`, `priority_tree_stl`, `priority_tree_log1p`, `priority_tree_class`.

**Effect** (`mcda/canopy_switch_effects.R`, outputs in `output/figures_mcda/canopy_switch_2026_11_23/`). Scored cells
10,194 (unchanged); Spearman with the previous score 0.811 (populated cells 0.868); top quintile retained 82.7% (85.1%);
53.4% of cells change quintile; population in top quintile cells 30.5% to 28.9%; street greenery share of the score in
top quintile cells 25.0% to 23.2%; citizen vs equal weights Spearman 0.923 to 0.950; burden coincidence (Step 3) ratio
0.987 to 0.989, street greenery top class 0% to 20.0%. All five values of the consistency check against the canopy
notebook (Step 7a, option b, linear) match.
Burden coincidence notebook, Malta, old to new: A mean |Spearman| 0.237 to 0.245, top quintile of >= 3 criteria
22.9% vs 23.2% permuted (0.99) to 28.8% vs 29.2% (0.99); B random weights median Spearman 0.772 to 0.823, overlap
63.1% to 66.6%; C1 unchanged (street greenery is not a shared criterion); C2 change per unit of weight 0.81 to 0.53
(Klagenfurt 0.11), slope over draws 0.88 to 0.75; D robust core 1.2% to 1.7% of cells (residents 0.9% to 1.6%).

**Backups of the 2026-11-20 state** (in `../ggn_analysis_archive`, ignored by git):
- `data/malta/malta_mcda_processed_realloc_pre_canopy.rds`, md5 `8c0b09a10b8796d8fb2739cec5621ae1`
- `data/malta/malta_sensitivity_pre_canopy.rds`, md5 `df360222818415fc2214afed99c40eb2`
- `output/figures_mcda/_pre_canopy/`: paper figures (`Figure*_lancet.*`), `criterion_maps/`, `criterion_maps_paper/`,
  `burden_coincidence_2026_11_20/`, `data_malta_outputs/` (Figures 3 and 4, `contribution_table.rds`, survey summaries),
  `html/` (knitted scoring, Figures, Tables and burden notebooks, Tables 1, 2, S5, S6); 142 files, checksums in
  `output/figures_mcda/_pre_canopy/md5sums.txt`.
- New `data/malta/malta_mcda_processed_realloc.rds`, md5 `41fd841baab4c506657130be8ba56343`.

**HIA protection (decided 2026-11-23).** The current HIA outputs (re-run 2026-11-10) were built on the 2026-11-06
score, `data/malta/malta_mcda_processed_realloc_pre_nov19.rds` (md5 `7df4bad8bacd71ee0f5c8c2c0ea6cc6b`). Every HIA
reader now points to that file, so a re-knit reproduces the current HIA outputs: `analysis/HIA_malta_main.Rmd` (line 153,
`MCDA_RDS`), `analysis/05_mcda_overlap_malta.Rmd` (lines 66 and 316), `analysis/03_scenarios_malta.Rmd` (line 557),
`analysis/CA_GAM_monotone_test.Rmd` (line 54), `HIA_plots_slides.Rmd` (line 63), `analysis/slides/delta_ga_maps.Rmd`
(line 89), `analysis/slides/build_district_scenario_maps.R` (line 85). **The HIA was not re-knitted.** It will be rerun
once, on the final Malta score, after both the street greenery and the traffic changes are in.

**Also changed.** `mcda/street_greenery_canopy_malta.Rmd` reads the `_pre_canopy` score (it rebuilds the Street Tree
Layer score as its reference). `mcda/criteria_maps_paper.R`: street greenery panel now maps `street_canopy_pct` (cap at
the p98 of eligible cells; grey = no street, not applicable), spec 8.3.

**Re-run:** `Malta_MCDA_260702_realloc.Rmd`, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`, `criteria_maps_paper.R`,
`Burden_coincidence_random_weights.Rmd`. Klagenfurt unchanged (its outputs in the shared figures and tables are
regenerated from the unchanged Klagenfurt score).

**Prose not updated (TODO markers):** scoring notebook "Tree cover" section, correlation matrix (still `perc_tree`),
"Difference" paragraph; Table 1 of `Tables_MCDA.Rmd`.

**Not repointed, flagged:** `wp6_update_nov2026/numbers_wp6.R` and `figures_wp6.R` read the main score file; they will
pick up the canopy score if re-run. `analysis/00_check_malta_grid.R` reads the main file for the grid check only.

## 2026-11-24: CAMS-REG traffic check run, no score changed

New notebook `mcda/traffic_cams_reg_check.Rmd` (instruction `mcda/Traffic_instructions.Rmd`), outputs in
`output/figures_mcda/traffic_cams_reg_check/`. Data: CAMS-REG road transport v8.1 (Hohenberger et al. 2026),
Zenodo record 19337413 (latest version of 10.5281/zenodo.15688722), md5 checked, in `../ggn_analysis_archive/cams_reg/`
(not in git), read with a spatial filter; clipped extracts cached there.

- Both countries present (MLT 14,602 links, AUT 10,931). AADT field `trafficvol_final`; Malta has OpenTransportMap
  matched links (`osm_otm` and `otm`, 393 km, all trunk to tertiary); residential and living streets are gap filled
  (`smallroads_4`), service and track `smallroads_5`. No `unclassified` class in CAMS-REG (Malta 182 km, Klagenfurt
  70 km of our OSM unclassified roads have no CAMS-REG link within 10 m).
- Levels far below official counts: Malta Regional Road median 2,391 vs about 57,000 vehicles per day (2019, AIS
  Environment), ratio 0.04; Klagenfurt 22 Carinthia stations (JDTV 2019, Land Kärnten), median ratio 0.11.
- Ranks contradicted in Klagenfurt: Spearman across stations -0.205 (road matched links), -0.023 (highest main road
  link within 30 m). Decision rule (fixed in advance): CAMS-REG does not become the main traffic source.
- Cell indicator (vehicle km per day, without service and track) vs current criterion: Spearman Malta 0.643,
  Klagenfurt 0.506; top quintile overlap 72.5% and 43.4%.

No score, normalisation, notebook or HIA file was changed.

Units check (same day, section "Units check" in the same notebook, not re-knitted): `trafficvol_final x road_length / 1000`
equals `vkm_abs_sum_speed_based_urh` on every link (the Readme's "thousands/day" for `vkm_*` is wrong). Doubling CAMS-REG
on oneway links: station Spearman -0.144. Current criterion at the same 22 stations: Spearman 0.125.

## 2026-11-24: road type traffic exploration, no score changed

New notebook `mcda/traffic_road_type.Rmd` (instruction `mcda/Traffic_instructions.Rmd`, section 2, Option B; the
instruction file was reorganised the same day: status of what was tested, the active instruction, open decisions,
and the CAMS-REG instruction as an appendix). Outputs in `output/figures_mcda/traffic_road_type/`.
Roads: the walking OSM extracts (Malta 5 November, Klagenfurt 11 November 2026), motor classes only, clipped to
the study areas. Each cell takes the highest class with at least 10 m inside it; candidates K2 to K5 as in the instruction.

- All four candidates meet criteria 1 to 3 (every class at least 2% of eligible cells; all 22 Klagenfurt stations in
  the top or second class; |Spearman| with NO2 and noise at most 0.59).
- Spearman with the current criterion: Malta 0.80 to 0.83, Klagenfurt 0.74 to 0.79. Priority score in memory:
  Spearman 0.970 to 0.988 with the current score, top quintile overlap 81.0% to 90.0%.
- Top class share (eligible cells): Malta K2 18.3%, K3 10.8%, K4 and K5 7.4%; Klagenfurt K2 10.1%, K3 6.3%, K4 and K5 2.2%.
- All Klagenfurt B roads are OSM primary, so road type cannot rank the stations (a single class).

No score, normalisation, existing notebook or HIA file was changed.

## 2026-11-24: traffic switched to OSM road type K3 in both scores (spec 3.4)

**What changed.** Traffic in both cities (`norm_traffic` in Malta, `norm_traffic_cat` in Klagenfurt) is now OSM road
type in three classes (K3): main (motorway, trunk, primary) = 1; distributor (secondary, tertiary) = 0.5; local
(unclassified, residential, living_street) or no kept road = 0. Each cell takes the highest kept road with at least
10 m inside it. Roads: the walking network extracts (`own_routing/osm_highways_raw.gpkg`; Malta 5 November, Klagenfurt
11 November 2026), clipped to the study area. Tunnels excluded (any `tunnel` value other than no, or `covered = yes`;
the extracts have no tunnel column, so the tags come from a new Overpass query of 24 November 2026, OSM base
2026-11-24T15:33Z, saved as `own_routing/osm_tunnel_covered_tags_2026-11-24.json` in each city): Malta 67 ways, 4.9 km
(Triq Reġjonali 1.8 km, Triq l-Ewwel Titjira 0.8 km, Sun Yat-Sen tunnel 0.6 km), 20 cells change class; Klagenfurt 28
ways, 12.0 km (Ehrentalerbergtunnel 6.7 km, Falkenbergtunnel 2.2 km, Unterflurtrasse Lendorf 1.6 km and Trettnig 0.9 km),
83 cells change class. Built by the new script `mcda/traffic_road_type_k3.R` (one function, sourced by both scoring
notebooks). Kept for the sensitivity analysis: `norm_traffic_k2`, `norm_traffic_k5`, `norm_traffic_cams` (CAMS-REG vehicle
km, log10(x + 1), min max 0 to p98, from `output/figures_mcda/traffic_cams_reg_check/traffic_vkm_*_cams.csv`), and the
previous OpenTransportMap classes as `norm_traffic_otm` (Malta) and `norm_traffic_cat_otm` (Klagenfurt). Weights,
spec 4.2, spec 1.3 and quintiles unchanged. Spec 3.4 and 5.3 updated.

**Why.** Neither OpenTransportMap (the previous criterion) nor CAMS-REG reproduced the order of the 22 Carinthia
counting stations (Spearman about 0.1 and -0.21; `traffic_cams_reg_check.Rmd`). K3 was chosen among four road type
candidates (`traffic_road_type.Rmd`): all 22 stations in the top class, |rho| with NO2 and noise below 0.70.

**Consistency check** against `traffic_road_type.Rmd` Step 3f (no tunnel rule), new score vs `_pre_roadtype`: Malta
Spearman 0.983 (expected 0.983), top quintile retained 84.3% (84.3%); Klagenfurt 0.974 (0.978), 85.3% (85.3%). Without
the tunnel rule the K3 classes equal the exploration notebook's in every cell.

**Effect** (`mcda/traffic_k3_switch_effects.R`, outputs in `output/figures_mcda/traffic_k3_switch_2026_11_24/`), old to new:
- Scored cells unchanged (Malta 10,194; Klagenfurt 11,996). Cells changing quintile by 2 or more: Malta 25 (0.2%),
  Klagenfurt 141 (1.2%).
- Population in top quintile cells: Malta 28.9% to 27.7%; Klagenfurt 50.1% to 49.4%.
- Traffic share of the score in top quintile cells: Malta 8.2% to 12.2%; Klagenfurt 6.6% to 12.1%.
- Citizen vs equal weights Spearman: Malta 0.950 to 0.957; Klagenfurt 0.976 to 0.977.
- Leave one out, without traffic: Malta 0.978 to 0.960; Klagenfurt 0.973 to 0.950.
- Traffic variants vs the new score (Spearman, top quintile retained): Malta K2 0.984, 87.2%; K5 0.997, 93.0%;
  CAMS-REG 0.975, 82.8%; OpenTransportMap 0.983, 84.3%. Klagenfurt K2 0.987, 92.9%; K5 0.998, 94.6%; CAMS-REG 0.974,
  86.6%; OpenTransportMap 0.974, 85.3%.
- Step 3 (burden coincidence): traffic top class share Malta 20.9% to 10.7%, Klagenfurt 8.1% to 13.6% (tie rule:
  only the main class is above p80); ratio to shuffled Malta 0.989 to 0.952, Klagenfurt 1.424 to 1.355.
- Burden coincidence notebook: B random weights median Spearman Malta 0.823 to 0.831, Klagenfurt 0.875 to 0.880;
  C2 change per unit of weight Malta 0.53 to 0.46, Klagenfurt 0.11 to 0.10; D robust core Malta 1.7% to 2.4% of cells
  (residents 1.6% to 2.0%), Klagenfurt 5.4% to 4.9% (residents 16.8% to 17.3%).
- No criterion pair reaches |rho| = 0.70 except the known ones (Malta green per person and green proximity 0.79;
  Klagenfurt NO2 and PM2.5 0.76, both within air quality).

**Backups of the 2026-11-23 state** (`../ggn_analysis_archive`, ignored by git):
- `data/malta/malta_mcda_processed_realloc_pre_roadtype.rds`, md5 `41fd841baab4c506657130be8ba56343`
- `data/malta/malta_sensitivity_pre_roadtype.rds`, md5 `1431571da6ebc91a6652150470a94a24`
- `data/klagenfurt/klagenfurt_mcda_priority_may_pre_roadtype.rds`, md5 `2c8cfddd8e5898053c61f4d10317f675`
- `data/klagenfurt/klag_sensitivity_pre_roadtype.rds`, md5 `7ee6f21888ae1f19a673e98e026ee72e`
- `output/figures_mcda/_pre_roadtype/`: paper figures, `criterion_maps/`, `criterion_maps_paper/`,
  `burden_coincidence_2026_11_20/`, `data_malta_outputs/`, `html/`; 142 files, checksums in `md5sums.txt`.
- New: `malta_mcda_processed_realloc.rds` md5 `e88da46ee2f7c1e3a81417d5e6ba25dc`, `malta_sensitivity.rds`
  `1f679f1dcaca2f6f7eb5a91873534821`, `klagenfurt_mcda_priority_may.rds` `0ef84be5dfd1b05cd5b0da23bc81f771`,
  `klag_sensitivity.rds` `6d1210f0e5aa6929d68c46daeeae00e5`.

**HIA.** Not touched or re-run. The Malta HIA notebooks still read `malta_mcda_processed_realloc_pre_nov19.rds`
(md5 `7df4bad8`). `analysis/HIA_klagenfurt.Rmd`, `analysis/Scenario_MCDA_overlap_klagenfurt.Rmd` and
`analysis/MCDA_scenarios_targeted_klagenfurt.Rmd` are legacy (no Klagenfurt HIA planned) and will read the K3 score if
re-knitted; the WP6 scripts (`wp6_update_nov2026/numbers_wp6.R`, `figures_wp6.R`) will also use the new scores.

**Re-run:** both scoring notebooks, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`, `Burden_coincidence_random_weights.Rmd`,
`criteria_maps_paper.R` (traffic panel now three classes, discrete legend, one palette for both cities).

**Prose not updated (TODO markers):** traffic text and the "categorical vs log" sections of both scoring notebooks
(those sections still run but are no longer in Table S6); Table 1 traffic row in `Tables_MCDA.Rmd`.

## 2026-11-25: burden coincidence Step 3, fractional tie rule and restricted shuffle; CAMS-REG cell CSV moved to data/

**Step 3 tie rule (`Burden_coincidence_random_weights.Rmd`, spec 5.4).** For each criterion, over the cells where it
is defined (scored and not missing), cells strictly above the value that contains the 20% boundary have membership 1,
cells at the boundary value (class or tie) membership f = (0.20 minus share strictly above) / share at the boundary
value, all others 0. Cells with a criterion score of 0 (no burden) never get membership: if the 20% boundary falls in
the zero class, the criterion keeps only the cells above it (f = 0). Every other criterion now has exactly 20%
membership (before: at or above p80, strictly above p80 if that class exceeded 25%). Only traffic changes in practice:

| City | Criterion | Strictly above | At boundary value | f | Old share | New share |
|---|---|---|---|---|---|---|
| Malta | Traffic (boundary = distributor, 0.5) | 10.7% | 16.5% | 0.564 | 10.7% | 20.0% |
| Klagenfurt | Traffic (boundary = local or no road, 0: zero rule) | 13.6% | 86.4% | 0 | 13.6% | 13.6% |

Zero rule added the same day (first version gave Klagenfurt traffic f = 0.074 spread over the 86.4% of cells with
no main or distributor road, i.e. cells with no traffic burden counted as partly burdened).

All other criteria had old shares of 20.0% (continuous, ties of 1 to 15 cells at the boundary). Malta street
greenery (street canopy since 2026-11-23) is no longer tied at maximum.

**Count of cells with three or more burdens.** Memberships are independent probabilities within a cell; the count
is the sum over cells of P(3 or more) (Poisson binomial), for the observed data and for each shuffle.

**Restricted shuffle.** Each criterion is shuffled only among the cells where it is defined (before: across all
scored cells). Matters for Malta green per person (defined in 46.9% of scored cells), recreation (98.4%), green
proximity (99.2%) and Klagenfurt green proximity (97.8%).

**Effect** (200 shuffles, seed 20261120; % of scored cells; tables and figure in Step 3b, outputs
`A3_tie_rule_shuffle_variants.csv`, `A3a_tie_rule_shares.png`, `A3b_ratio_variants.png`):

| City | Variant | Observed | Shuffled mean (p5 to p95) | Ratio |
|---|---|---|---|---|
| Malta | Old tie rule + old shuffle (reported to 24 Nov) | 24.9 | 26.1 (25.7 to 26.5) | 0.952 |
| Malta | New tie rule + old shuffle | 28.4 | 28.9 (28.5 to 29.3) | 0.984 |
| Malta | Old tie rule + restricted shuffle | 24.9 | 26.1 (25.6 to 26.6) | 0.952 |
| Malta | **New tie rule + restricted shuffle (main)** | 28.4 | 28.9 (28.4 to 29.3) | 0.984 |
| Klagenfurt | Old tie rule + old shuffle (reported to 24 Nov) | 11.6 | 8.5 (8.2 to 8.9) | 1.355 |
| Klagenfurt | New tie rule + old shuffle | 11.5 | 8.5 (8.2 to 8.9) | 1.355 |
| Klagenfurt | Old tie rule + restricted shuffle | 11.6 | 8.5 (8.2 to 8.8) | 1.356 |
| Klagenfurt | **New tie rule + restricted shuffle (main)** | 11.5 | 8.5 (8.2 to 8.8) | 1.356 |

Main ratio with the zero rule vs the first version of the same day (no zero rule): Malta 0.984 vs 0.984 (no
criterion has its boundary in the zero class); Klagenfurt 1.356 vs 1.276 (traffic no longer spreads 6.4% membership
over no burden cells). The old tie rule with the old shuffle reproduces the 24 November values exactly. The tie rule
moves Malta towards 1 (0.952 to 0.984) and leaves Klagenfurt where it was (1.355 to 1.356); the restricted shuffle
changes the ratios by 0.001 or less. Parts A1, A2,
B, C and D of the notebook are unchanged (checked against the previous outputs). No score changed.

**CAMS-REG cell CSV moved to data/.** `traffic_vkm_malta_cams.csv` and `traffic_vkm_klagenfurt_cams.csv` copied
from `output/figures_mcda/traffic_cams_reg_check/` (written by `traffic_cams_reg_check.Rmd`) to `data/malta/` and
`data/klagenfurt/`; md5 identical (Malta `94c6890e0a8a432f9fb3006e7158806e`, Klagenfurt
`812968c9f37594d88563ada3eb2fec52`). Both scoring notebooks now read the `data/` copies; only the read lines were
re-run, and `traffic_vkm_cams` is identical to the column in both saved scores. `traffic_cams_reg_check.Rmd` still
writes to `output/` (not changed).

**Backups** of the previous burden coincidence outputs and HTML:
`output/figures_mcda/burden_coincidence_2026_11_20/_pre_tie_rule_2026_11_25/`.

**Archived:** `mcda/burden_coincidence_random_weights.R` (untracked script version of the notebook, still with the old
Step 3) moved to `analysis/archive/R/`.

## 2026-11-25: water cells join the constraint, both cities (spec 1.3)

**What.** Cells whose majority Urban Atlas class is water (50000) are not eligible for greening and are not scored,
in both cities, with the same majority rule as the Malta airport and port constraint (class of the largest Urban
Atlas piece in the cell). Malta: airport (12400), port (12300) or water, Urban Atlas 2021. Klagenfurt: water only, its
first constraint. Constraint cells are excluded from every normalisation bound (min, p2, p98). In Malta this is also
new for the airport and port cells in five main criteria (urban heat, blue space, noise, NO2, recreation) and two
sensitivity variants (Street Tree Layer, green per person min max), which until now took bounds over all cells.
Shared function `mcda/ua_constraint.R`, sourced by both scoring notebooks. Instruction: `mcda/Water_constraint_instructions.Rmd`.

**Why.** Water cannot be greened; open water cells entered the score (Malta 274 of 276 water cells were scored, 14 in
the top quintile; Klagenfurt all 144, 1 in the top quintile).

**Klagenfurt source: Urban Atlas 2018.** The Urban Atlas 2021 land use layer of Klagenfurt is not on the server
(ATGreen read it from `/Users/rschifan/.../extracts/klagenfurt/urban_atlas/urban_atlas_2021.parquet`; only its green
class extract, classes 14110, 14130, 31000 and 32000, is here) and the Copernicus site was down on 25 November 2026.
Klagenfurt water cells therefore come from Urban Atlas 2018: `../ggn_analysis_archive/data_raw/urban_atlas_2018/Land_uses.zip`,
member `Land_uses/UBD_urbanatlas_2018_0.feather` (16 January 2025; m2 of each of the 27 Urban Atlas 2018 classes per
100 m cell, water = 50000; the Urban Atlas 2018 version is not recorded in the file). Extracted by the new script
`mcda/klagenfurt_ua2018_cells.R` to `data/klagenfurt/klagenfurt_ua2018_class_area_cells.csv` (md5
`7b0577a75c22c6de99dab75358ea5c83`; 11,996 cells, linked to `ID` by centroid, grids coincide within 0.2 m; the other
422 cells have no row and none is scored). Each class is one piece, so the majority is the class with the largest
area. To be checked against Urban Atlas 2021 when it can be downloaded.

**Counts** (tables and figures in `output/figures_mcda/water_constraint_2026_11_25/`, script `mcda/water_constraint_effects.R`):

| | Malta | Klagenfurt |
|---|---|---|
| Water cells (majority class) | 276 | 144 |
| Water share > 50% instead (information only) | 240 (36 cells differ) | 140 (4 differ) |
| Constraint cells, old to new | 459 to 735 | 0 to 144 |
| Eligible cells, old to new | 10,198 to 9,922 | 12,418 to 12,274 |
| Scored cells, old to new | 10,194 to 9,920 | 11,996 to 11,852 |
| Population in water cells | 1,751 (49 cells) | 27 (9 cells) |
| Old quintile of water cells, Q1 to Q5 (not scored) | 164, 39, 40, 17, 14 (2) | 115, 22, 5, 1, 1 (0) |
| Population in scored cells, old to new | 344,731 to 342,979 | 103,229 to 103,202 |
| Spearman old vs new (cells scored in both) | 1.000 | 1.000 |
| Top quintile overlap old vs new | 98.0% | 98.8% |
| Cells changing quintile (by 2 or more) | 3.2% (0) | 2.1% (0) |
| Citizen vs equal weights, Spearman (old to new) | 0.957 to 0.956 | 0.977 to 0.977 |
| Citizen vs equal weights, top quintile overlap | 83.4% to 83.6% | 92.2% to 92.0% |
| Step 3 main ratio (old to new) | 0.984 to 0.974 (0.960 to 0.989) | 1.356 to 1.369 (1.327 to 1.417) |

Top 5 units by share of top quintile cells (units with at least 20 scored cells): Malta Isla drops out (13 scored cells
left, 7 water cells removed), Fgura enters at rank 5; Klagenfurt district 20101562 drops out (quintile breaks shift),
20101188 enters. Main bounds that changed most: Malta urban heat min 28.67 to 29.12 and p98 50.67 to 50.18 C, NO2 p98
35.25 to 34.95; Klagenfurt OpenTransportMap log p98 572 to 580 (sensitivity), low income p98 33,651 to 33,639. Klagenfurt
LST and raw income bounds unchanged. Full list in `normalisation_bounds.csv`. Sensitivity set (spec 5.3): every row
within 0.005 of its old Spearman (`sensitivity_old_new.csv`).

**Backups of the 2026-11-25 pre water state** (`../ggn_analysis_archive`, ignored by git):
- `data/malta/malta_mcda_processed_realloc_pre_water.rds`, md5 `e88da46ee2f7c1e3a81417d5e6ba25dc`
- `data/malta/malta_sensitivity_pre_water.rds`, md5 `1f679f1dcaca2f6f7eb5a91873534821`
- `data/klagenfurt/klagenfurt_mcda_priority_may_pre_water.rds`, md5 `0ef84be5dfd1b05cd5b0da23bc81f771`
- `data/klagenfurt/klag_sensitivity_pre_water.rds`, md5 `6d1210f0e5aa6929d68c46daeeae00e5`
- `output/figures_mcda/_pre_water/`: paper figures, `criterion_maps/`, `criterion_maps_paper/`,
  `burden_coincidence_2026_11_20/`, `data_malta_outputs/`, `html/`; 164 files, checksums in `md5sums.txt`.
- New: `malta_mcda_processed_realloc.rds` md5 `1329cac39d0ad139f233d939cc925fdd`, `malta_sensitivity.rds`
  `d9f4785819d1d5b55c03ac79e0a3dab7`, `klagenfurt_mcda_priority_may.rds` `a8343c1cdfddfbe792cced08f320a6b0`,
  `klag_sensitivity.rds` `ef68b6407b6bedda8f3881ab8babe4b2`.

**HIA.** Not touched or re-run; `malta_mcda_processed_realloc_pre_nov19.rds` md5 `7df4bad8` checked after the run.

**Re-run:** both scoring notebooks, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`, `Burden_coincidence_random_weights.Rmd`,
`criteria_maps_paper.R`.

**Prose not updated (TODO markers):** Malta eligibility heading and text (airport and port only), Malta green per person
min max sensitivity text ("p98 over all cells"), Burden coincidence map caption ("mainly the airport and port").
Not changed: the criterion map legends (`criteria_maps_paper.R`) still take some display limits over all cells.

## 2026-11-25 (later): one majority rule for both cities; industrial and Street View checks; green per person sensitivity; 4 km/h removed

Instruction: `mcda/instructions/2026_11_25_industrial_streetview_gpp_sensitivity.md` (saved verbatim).

**Part 0. Majority class = largest total area in the cell (spec 1.3), both cities.** `mcda/ua_constraint.R`
(`ua_majority`) now sums the Urban Atlas pieces of each cell by class and takes the class with the largest total
area (first class on ties); Malta used the class of the largest single piece until now. Klagenfurt (Urban Atlas 2018
class table) is unchanged. Malta majority class changes in 559 cells; constraint cells:

| | Old | New |
|---|---|---|
| Malta airport | 358 | 357 |
| Malta port | 101 | 99 |
| Malta water | 276 | 268 |
| Malta total (eligible) | 735 (9,922) | 724 (9,933) |
| Klagenfurt water (eligible) | 144 (12,274) | 144 (12,274) |

11 Malta cells leave the constraint, none enter. Scored cells: Malta 9,920 to 9,931; Klagenfurt 11,852 (unchanged).
Old vs new (cells scored in both): Malta Spearman 1.000, top quintile overlap 99.8%, 0.1% of cells change quintile;
Klagenfurt identical. Step 3 main ratio: Malta 0.974 (0.960 to 0.989) to 0.974 (0.961 to 0.987); Klagenfurt 1.369
(1.327 to 1.417), unchanged. Tables and figures: `output/figures_mcda/majority_rule_2026_11_25/`, script
`mcda/majority_rule_effects.R`.

**Spec 3.4 and 8.3.** Bounds over eligible cells only (already in the code since the water constraint) written into
3.4. `criteria_maps_paper.R`: legend limits (NO2, blue space, walking time, LST, noise, recreation, Klagenfurt air
quality composite, PM2.5, income) now over eligible cells only, as the score's bounds; spec 8.3 updated.

**Part C. Sensitivity: Malta green per person = 0 (not applicable) in unpopulated cells** instead of missing,
consistent with the street greenery rule (spec 4.2); scored set recomputed with the available weight rule
(`priority_gpp_na0`, new chunk `green-exp-na0-sensitivity` in `Malta_MCDA_260702_realloc.Rmd`, new row in
`malta_sensitivity.rds`, spec 5.3). Scored cells 9,931 (main) and 9,933 (variant; 2 newly scored, none in the top
quintile). Spearman 0.988, top quintile overlap 87.6%, 16.7% of cells change quintile, none by 2 or more. Top 5
councils by share of top quintile cells: main Hamrun 62.3%, Marsa 49.4%, Santa Venera 44.9%, Msida 42.0%, Fgura 35.7%;
variant Hamrun 65.1%, Santa Venera 50.6%, Marsa 48.5%, Msida 46.6%, Fgura 42.0%.

**Part D. Walking speed 4 km/h sensitivity removed** from both scoring notebooks, both sensitivity files and spec
5.3. Reason (decision of 25 November 2026): walking time is min max normalised, so a uniform change of speed rescales
all times and leaves the criterion scores unchanged. Note: in Malta the variant also recomputed green per person with
the E2SFCA catchment fixed in minutes (Gaussian sigma 5 min, cutoff 15 min), which does change at 4 km/h (Spearman
0.998, top quintile retained 96.2% on 24 November); that part is not covered by the reason above. The input column
`green_m2_e2sfca_gauss_newpop_4kmh` is still written by `mcda/malta_e2sfca_newpop.R` (not re-run) and is no longer read.

**Parts A and B.** New notebook `mcda/checks_industrial_streetview.Rmd` (no score file changed; outputs in
`output/figures_mcda/checks_industrial_streetview_2026_11_25/`):
- A. Industrial cells (majority class 12100, Part 0 rule): Malta 1,437 (1,436 scored; 409 with no kept street, 334 of
  them with OSM service roads inside; 24,601 residents); Klagenfurt 1,191 (Urban Atlas 2018; no street greenery
  criterion; 355 without kept street classes, 285 with service roads; 14,334 residents). Malta: service roads counted as
  streets in industrial cells only (in memory): Spearman 0.972 with the current score, top quintile overlap 95.9%, 432
  industrial cells change quintile; industrial cells in Q1 10.2% to 3.5%, Q5 36.0% to 39.9%. Klagenfurt industrial
  cells: 58.4% in Q5. No decision taken.
- B. Street View sample, Malta (seed 20261125): 10 cells at 0%, 10 above 0 to 8.5% (median of cells above 0), 10 above
  17.5% (p80), and 5 Valletta cells between 15 and 25% (12 in the pool). Panels (canopy 3 m on Esri World Imagery, 10 m
  street buffer, cell) in `streetview_panels/` (35 PNG and one PDF); CSV `mcda/output/streetview_sample.csv` with empty
  columns trees_visible, agrees_with_indicator, note for manual review.

**Part E. Analyses A to D on the final scores.** `Burden_coincidence_random_weights.Rmd` re-knitted 2026-11-25 13:43 on
`data/malta/malta_mcda_processed_realloc.rds` (md5 `905c359a07f627df6183759df1eec63e`, written 13:35) and
`data/klagenfurt/klagenfurt_mcda_priority_may.rds` (md5 `eb0ba7f44bef9fd5cbc2af1fe240c08c`, written 13:37); the
notebook now prints the path, md5 and date of the score files it reads. Headline numbers in `partE_*.csv`.

**Backups of the pre majority state** (`../ggn_analysis_archive`, ignored by git):
- `data/malta/malta_mcda_processed_realloc_pre_majority.rds`, md5 `1329cac39d0ad139f233d939cc925fdd`
- `data/malta/malta_sensitivity_pre_majority.rds`, md5 `d9f4785819d1d5b55c03ac79e0a3dab7`
- `data/klagenfurt/klagenfurt_mcda_priority_may_pre_majority.rds`, md5 `a8343c1cdfddfbe792cced08f320a6b0`
- `data/klagenfurt/klag_sensitivity_pre_majority.rds`, md5 `ef68b6407b6bedda8f3881ab8babe4b2`
- `output/figures_mcda/_pre_majority/`: 164 files, checksums in `md5sums.txt`.
- New: `malta_mcda_processed_realloc.rds` `905c359a07f627df6183759df1eec63e`, `malta_sensitivity.rds`
  `9b78137584ac97d682662def2e9c0013`, `klagenfurt_mcda_priority_may.rds` `eb0ba7f44bef9fd5cbc2af1fe240c08c`,
  `klag_sensitivity.rds` `04d71544092be3f9813a957e5cab8c80`.

**HIA.** Not touched; `malta_mcda_processed_realloc_pre_nov19.rds` md5 `7df4bad8` checked.

**Re-run:** both scoring notebooks, `Figures_MCDA.Rmd`, `Tables_MCDA.Rmd`, `Burden_coincidence_random_weights.Rmd`,
`criteria_maps_paper.R`, `mcda/majority_rule_effects.R`, `mcda/checks_industrial_streetview.Rmd`.

## 2026-11-25 (evening): Klagenfurt equal weights at the criterion level (spec 2.3); random weights histograms

**Klagenfurt equal weights.** `Klagenfurt_MCDA_260520.Rmd` built `priority_equal` with 1/7 per indicator (air quality
2/7, NO2 and PM2.5 counted as two criteria). Fixed to spec 2.3: 1/6 per criterion, air quality split 1/12 NO2 + 1/12
PM2.5 (decision of 25 November 2026; flagged 2026-11-20). The equal weight columns of the weight tables (sections 7.1,
7.4) now show these values. `priority_citizen` is bit identical; only `priority_equal` and `weight_diff` change.

| Klagenfurt, citizen vs equal weights | Old (1/7 per indicator) | New (1/6 per criterion) |
|---|---|---|
| Spearman | 0.977 | 0.990 |
| Top quintile overlap | 92.0% | 93.4% |
| Cells changing quintile | 20.7% | 15.2% |

The new values match `Burden_coincidence_random_weights.Rmd` C2b, which already used 1/6 per criterion. All other
rows of `klag_sensitivity.rds` (14 rows) are unchanged. Malta is not affected.

**Random weights figures.** In `Burden_coincidence_random_weights.Rmd` the violin plots of B and C1 are replaced by
histograms (spec 8.1; `B_spearman_hist`, `B_overlap_hist`, `C1_spearman_hist`, `C1_overlap_hist`, PNG and PPTX) with
the median and the citizen weights value, and a table of the percentile of the citizen weights value among the 1,000
random draws (`B_C1_citizen_percentile.csv`). `B_C1_random_weights.png` is no longer written.

**Backups** (`../ggn_analysis_archive`, ignored by git):
- `data/klagenfurt/klagenfurt_mcda_priority_may_pre_equal_criterion.rds`, md5 `eb0ba7f44bef9fd5cbc2af1fe240c08c`
- `data/klagenfurt/klag_sensitivity_pre_equal_criterion.rds`, md5 `04d71544092be3f9813a957e5cab8c80`
- New: `klagenfurt_mcda_priority_may.rds` `d741811031c8ffefacf7d71fd7015e46`, `klag_sensitivity.rds`
  `9dcfa634fea12fe306aba160e64cd854`.

**Re-run:** `Klagenfurt_MCDA_260520.Rmd`, `Tables_MCDA.Rmd` (Table S6), `Burden_coincidence_random_weights.Rmd`.
`Figures_MCDA.Rmd` does not read `priority_equal` and was not re-run. Not re-run (historical records of earlier
states): `poster_UT2026_numbers.R`, `traffic_k3_switch_effects.R`, `water_constraint_effects.R`,
`majority_rule_effects.R`, `canopy_switch_effects.R`.

**HIA.** Not touched.

## 2026-11-25 (evening): budget allocation style; sensitivity row "Weights: median instead of mean" (spec 5.3)

New notebook `mcda/survey_allocation_style.Rmd` (outputs in `output/figures_mcda/survey_allocation_style_2026_11_25/`),
same respondents as the weights (Malta 123, Klagenfurt 184). Descriptive only: budget and city are confounded.

**Part 0.** Survey code (`GreenSpace/Codes/MCDA_MM/city_surveys/`, checked 26 November 2026): one slider per
criterion starting at 0, step 2% of the budget (20 euros in Malta, 20,000 euros in Klagenfurt), maximum 50% per
criterion, capped at the remaining budget; the preview button leading to submission is disabled until the total
equals the budget exactly. The raw data agree: all allocations on the 2% grid, maximum 50%, every respondent
allocated exactly the full budget. Distinct allocation values: Malta 23, Klagenfurt 26. One blank
Klagenfurt allocation is read as 0, as in the scoring notebook.

**Part A.** Malta vs Klagenfurt: gave 0 to at least one criterion 77.2% vs 45.7%; highest share median 26% vs 30%
(Mann-Whitney p < 0.001); normalised entropy median 0.766 vs 0.883 (p < 0.001); non zero allocations at multiples
of 10% of the budget 40.7% vs 41.1% (on the 2% grid, multiples of 5% are the same values; chance level 20%);
exactly equal 1.6% vs 0.0% (the Klagenfurt equal split is not on the grid; as even as the grid allows 1.6% vs 1.1%).

**Part B. New sensitivity row** (spec 5.3): weights = median percentage share per criterion, rescaled to sum to
100%; same cells as the main score; Klagenfurt air quality split equally between NO2 and PM2.5. Malta blue space has
a median share of 0, so it gets weight 0 in this variant.

| Weights: median instead of mean | Malta | Klagenfurt |
|---|---|---|
| Spearman | 0.997 | 1.000 |
| Top quintile retained | 95.9% | 98.0% |
| Cells changing quintile | 8.2% | 2.9% |

The rows are written to `data/citydata_outputs/median_weights_sensitivity.rds` and appended to Table S6 by
`Tables_MCDA.Rmd`; the scoring notebooks, score files and `*_sensitivity.rds` files are not changed. Spec 5.3 updated.
Re-run: `survey_allocation_style.Rmd`, `Tables_MCDA.Rmd`.

## 2026-11-26: Malta street greenery, class rule sensitivity variant dropped

Decision (user, 26 November 2026): the Malta street greenery sensitivity variant "agricultural and open land
as not applicable" (Urban Atlas 2021 classes 21000, 22000, 23000, 24000, 32000, 33000 set to not applicable)
is dropped completely, because eligibility of farmland is a question for the whole map, not for one criterion.
The 2 m and 5 m canopy height variants and the other street greenery variants stay in Table S6.

- `Malta_MCDA_260702_realloc.Rmd`: removed `RURAL_UA`, `norm_tree_class`, the variant in "Street greenery
  variants" and `priority_tree_class`. Re-knitted. `priority_citizen` and every other column are bit identical;
  only `norm_tree_class` and `priority_tree_class` are gone from `malta_mcda_processed_realloc.rds`
  (md5 7ca617175db3e03322fc40836b461ea1), and `malta_sensitivity.rds` has 28 rows instead of 29
  (md5 7f309632053d30dea703203e2f6244b3). Backups `*_pre_drop_farmland.rds`.
- The dropped Table S6 row was: Spearman 0.876, top quintile retained 77.6%, cells changing quintile 50.7%.
- Spec 3.6 and 5.3 updated. `Tables_MCDA.Rmd` re-knitted (Table S6).
- Not changed: section 10d of `street_greenery_canopy_malta.Rmd` (exploratory derivation, kept as a record) and
  the 2026-11-23 entry above, which reports the variant as it was then.
