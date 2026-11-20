# MCDA paper: results specification

Standing rules for every analysis, table and figure of the MCDA paper (Malta and Klagenfurt). Every instruction file for this paper starts with "Follow MCDA_paper_results_spec.md". If an instruction contradicts this file, stop and ask before running.

Last updated: 20 November 2026.

## 1. Study areas and grid

1.1 Grid: 100 m cells. Malta 10,657 cells (38 local councils, ERA Environmental Noise Agglomeration extended to every intersecting council). Klagenfurt 12,418 distinct cells (Urban Audit 2018 boundary). Klagenfurt cells are identified by `ID` (unique). The 101 cells that were repeated 4 or 9 times (12,751 rows) were removed at source on 19 November 2026; the score file now has 12,418 rows, one per `ID`, and the scoring notebook stops if that changes. The `gid` column is not a cell identifier in Klagenfurt (missing in 422 cells, none of them scored): never use it to join or count. Always count and join by `ID`. Any file with another cell count (e.g. Malta 15,702, which had duplicated cells) is wrong: stop and report.

1.2 Population: Malta `pop_reallocated_nso` (GHSL 2020 reallocated to Urban Atlas residential cells, scaled to NSO Census 2021 council totals). Klagenfurt GHSL 2020.

1.3 Constraint: Malta airport and port cells (Urban Atlas 2021 classes 12400 and 12300, majority class per cell; 459 cells) are excluded as not eligible for greening. This is a constraint, separate from missing value handling. It applies to Malta only: there is no airport in the Klagenfurt study area.

## 2. Surveys and weights

2.1 Samples: Malta n = 123. Klagenfurt n = 184 (186 responses, 2 former residents excluded; inclusion criterion: current resident). Read n from the data in every figure and table; never hardcode it.

2.2 Weight = mean percentage of the total budget allocated to each criterion across respondents (budgets differ: Malta €1,000, Klagenfurt €1,000,000; always analyse as percentage shares).

2.3 Test of each weight against equal weight: one sample t test (Malta 10%, Klagenfurt 16.7%), report mean, 95% CI and p.

## 3. Criteria and indicators

3.1 Malta (10): urban heat (LST), air quality (NO2), traffic, green proximity (walking time), blue space distance, street greenery (tree cover per cell, `perc_tree`, Urban Atlas 2018 Street Tree Layer), grey infrastructure (imperviousness), green per person (E2SFCA), noise (Lden), recreation (walking distance to the nearest facility, `walk_dist_m`; under 300 m = lowest priority).

3.2 Klagenfurt (6): urban heat (LST), air quality (composite of NO2 and PM2.5, equal weight), traffic, green proximity (walking time), blue space distance, low income areas.

3.3 Green per person (Malta): the score uses the E2SFCA computed for this study (OpenStreetMap walking network, 5 km/h, Gaussian decay σ = 5 min, 15 min cutoff, Urban Atlas green spaces of at least 500 m², classes 14110, 14130, 31000, 40000, census anchored population `pop_reallocated_nso`). In Malta only green urban areas are present (14110 and 14130: 106 patches, 114 ha); the study area has no forest or wetland polygons. Urban Atlas is used instead of OSM because OSM overestimates green space in Malta: in field checks, polygons tagged as green were often abandoned land with sparse vegetation, too small, or private, and the OSM values (median about 74 m² per person) are too high compared with the literature. Walking time to green uses the same green urban areas and the same routing (see 3.5). ATGreen's indicator and the 3 band step version (1, 0.7, 0.4) are sensitivity analyses only. (Decided 19 November 2026; replaces the 5 November decision.) The min max normalisation of raw m² per person capped at p98 (the score's version until 19 November 2026) is kept as a sensitivity analysis.

3.4 Normalisation: all indicators to [0, 1], 1 = highest priority. Methods as in Supplementary Table S1 (min max capped at p98 by default, computed from the current data, never hardcoded; log for strongly skewed; traffic in 3 categories). Walking time to green: continuous, min max capped at p98, in both cities (decided 19 November 2026; Klagenfurt previously used 4 classes). Malta green per person: log10 of m² per person (no offset), bounds = p2 and p98 of the log over eligible populated cells, zero green per person = 1 (highest priority), missing in unpopulated cells (green per person is undefined where nobody lives; those cells are scored on the other criteria under 4.2). The same normalisation applies to the ATGreen and step variants (decided 19 November 2026).

3.5 Walking time to green (both cities, decided 20 November 2026): our own routing, as for green per person: OpenStreetMap walking network with the pedestrian filter in `mcda/walk_filter.R` (keeps ways with foot = yes, designated or permissive, including shared foot and cycle paths; always drops foot = no, access = private and access = military), shortest paths at 5 km/h, ATGreen's network origin points (every 50 m) and cell assignment (mean over the points in the cell; connector to the nearest point within 200 m; otherwise missing). An origin point inside a green patch has time 0, and a cell assigned to such a point gets 0 (no connector walk); the same rule applies to the E2SFCA travel times. Green classes 14110, 14130, 31000, 40000, at least 500 m², in both cities (class 32000 excluded). Normalisation: min max capped at the p98 of eligible cells (Malta airport and port excluded; all cells in Klagenfurt). ATGreen's walking time (Valhalla in Malta, OSRM in Klagenfurt with class 32000) is a sensitivity analysis only (`priority_atg_walk`).

## 4. Priority score

4.1 Weighted linear combination with citizen weights.

4.2 Missing values (available weight rule): a cell is scored only if its available criteria carry at least 80% of the total weight; score = sum(w_i * s_i) / sum(w_i) over available criteria. Missing is missing: never set to 0 or to the maximum.

4.3 Priority classes: quintiles within each city (Q5 = top priority). Quartiles belong to the HIA paper only.

## 5. Comparisons and sensitivity analyses

5.1 Rank agreement: Spearman (never Pearson), across scored cells.

5.2 Class agreement: percentage of the main map's top quintile cells that stay in the top quintile.

5.3 Sensitivity set: citizen vs equal weights; each weight ±20% (others rescaled to sum to 1); traffic excluded and log continuous; Klagenfurt raw median income; walking speed 4 km/h; Malta green per person variants (3.3); leave one out (each criterion dropped in turn, other weights rescaled to sum to 1; in Klagenfurt air quality drops NO2 and PM2.5 together; replaces the "without green per person" check, 20 November 2026); shared criteria only (the five criteria common to both cities, weights rescaled to sum to 1).

## 6. Descriptive statistics

6.1 Populated cells only, median and IQR.

6.2 Concentrations in µg/m³ (NO2 and PM2.5 separately, never the composite). WHO 2021 guidelines as the single benchmark for both cities.

## 7. Number format

7.1 Percentages one decimal (78.0%), weights one decimal, Spearman three decimals (0.924), p values as p < 0.001 or two decimals.

7.2 Ranges written with "to", not a dash.

## 8. Figures

8.1 Style: same as the HIA paper (`R/theme_lancet.R`), 8 pt, 180 mm wide, PNG 300 dpi + editable PPTX. Font: Arial where installed; otherwise the same font as the HIA figures in both papers.

8.2 Maps: draw the grid as a raster (no polygon seams, no cell borders); study area outline 0.3 pt dark grey; internal boundaries 0.15 pt light grey (Malta local councils only; no internal boundaries in Klagenfurt); outside the study area white; one scale bar per figure; no north arrow; no plot titles; legends with units.

8.3 Criterion maps: keep each criterion's own colour palette with a continuous scale, including walking time; skewed variables capped at p98; shared criteria use the same scale limits in both cities, except land surface temperature, which keeps its own scale per city (decided 19 November 2026). Each map shows the indicator exactly as the score reads it.

8.4 Priority maps: quintiles within each city; captions state that classes are not comparable between cities.

## 9. Reporting

9.1 Every run ends with a report: numbers, paths of new files, and any check that failed. Stop and report instead of guessing when an input or a rule is unclear.

9.2 Record each change of method in `mcda/CHANGELOG.md`.