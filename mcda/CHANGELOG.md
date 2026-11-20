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
