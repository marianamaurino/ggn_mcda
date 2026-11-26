# MCDA paper: results specification

Standing rules for every analysis, table and figure of the MCDA paper (Malta and Klagenfurt). Every instruction file for this paper starts with "Follow MCDA_paper_results_spec.md". If an instruction contradicts this file, stop and ask before running.

Last updated: 25 November 2026 (majority rule = largest total area and water constraint, spec 1.3; bounds over eligible cells, spec 3.4 and 8.3; sensitivity set, spec 5.3; burden coincidence Step 3, spec 5.4).

## 1. Study areas and grid

1.1 Grid: 100 m cells. Malta 10,657 cells (38 local councils, ERA Environmental Noise Agglomeration extended to every intersecting council). Klagenfurt 12,418 distinct cells (Urban Audit 2018 boundary). Klagenfurt cells are identified by `ID` (unique). The 101 cells that were repeated 4 or 9 times (12,751 rows) were removed at source on 19 November 2026; the score file now has 12,418 rows, one per `ID`, and the scoring notebook stops if that changes. The `gid` column is not a cell identifier in Klagenfurt (missing in 422 cells, none of them scored): never use it to join or count. Always count and join by `ID`. Any file with another cell count (e.g. Malta 15,702, which had duplicated cells) is wrong: stop and report.

1.2 Population: Malta `pop_reallocated_nso` (GHSL 2020 reallocated to Urban Atlas residential cells, scaled to NSO Census 2021 council totals). Klagenfurt GHSL 2020.

1.3 Constraint (decided 25 November 2026 for water): cells whose majority Urban Atlas 2021 class is airport (12400), port (12300) or water (50000) are not eligible for greening and are not scored. Malta: airport, port and water; Klagenfurt: water only (there is no airport in the Klagenfurt study area). Majority class = class with the largest total area in the cell (decided 25 November 2026, both cities, every constraint class; `mcda/ua_constraint.R`, shared by both cities). Klagenfurt water cells come from Urban Atlas 2018 (per cell class areas, `data/klagenfurt/klagenfurt_ua2018_class_area_cells.csv`), because the Urban Atlas 2021 land use layer of Klagenfurt was not available on 25 November 2026; to be checked against 2021 when it can be downloaded. Counts: Malta 724 cells (456 airport and port: 357 airport, 99 port; 268 water), 9,933 eligible; Klagenfurt 144 water cells, 12,274 eligible. Constraint cells are not scored, not used to compute any normalisation bound (min, p2, p98) and not in any quintile, statistic or Step 3 count. This is a constraint, separate from missing value handling.

## 2. Surveys and weights

2.1 Samples: Malta n = 123. Klagenfurt n = 184 (186 responses, 2 former residents excluded; inclusion criterion: current resident). Read n from the data in every figure and table; never hardcode it.

2.2 Weight = mean percentage of the total budget allocated to each criterion across respondents (budgets differ: Malta €1,000, Klagenfurt €1,000,000; always analyse as percentage shares).

2.3 Test of each weight against equal weight: one sample t test (Malta 10%, Klagenfurt 16.7%), report mean, 95% CI and p.

## 3. Criteria and indicators

3.1 Malta (10): urban heat (LST), air quality (NO2), traffic, green proximity (walking time), blue space distance, street greenery (see 3.6), grey infrastructure (imperviousness), green per person (E2SFCA), noise (Lden), recreation (walking distance to the nearest facility, `walk_dist_m`; under 300 m = lowest priority).

3.2 Klagenfurt (6): urban heat (LST), air quality (composite of NO2 and PM2.5, equal weight), traffic, green proximity (walking time), blue space distance, low income areas.

3.3 Green per person (Malta): the score uses the E2SFCA computed for this study (OpenStreetMap walking network, 5 km/h, Gaussian decay σ = 5 min, 15 min cutoff, Urban Atlas green spaces of at least 500 m², classes 14110, 14130, 31000, 40000, census anchored population `pop_reallocated_nso`). In Malta only green urban areas are present (14110 and 14130: 106 patches, 114 ha); the study area has no forest or wetland polygons. Urban Atlas is used instead of OSM because OSM overestimates green space in Malta: in field checks, polygons tagged as green were often abandoned land with sparse vegetation, too small, or private, and the OSM values (median about 74 m² per person) are too high compared with the literature. Walking time to green uses the same green urban areas and the same routing (see 3.5). ATGreen's indicator and the 3 band step version (1, 0.7, 0.4) are sensitivity analyses only. (Decided 19 November 2026; replaces the 5 November decision.) The min max normalisation of raw m² per person capped at p98 (the score's version until 19 November 2026) is kept as a sensitivity analysis.

3.4 Normalisation: all indicators to [0, 1], 1 = highest priority. Methods as in Supplementary Table S1 (min max capped at p98 by default, computed from the current data, never hardcoded; log for strongly skewed). Normalisation bounds are computed over eligible cells only (constraint cells excluded; spec 1.3, 25 November 2026). Traffic (both cities, decided 24 November 2026): OSM road type in three classes from the walking network extracts, highest kept road with at least 10 m in the cell, tunnels excluded: main (motorway, trunk, primary) = 1; distributor (secondary, tertiary) = 0.5; local (unclassified, residential, living_street) or no road = 0. Replaces the OpenTransportMap volume classes, which did not reproduce the order of the Carinthia counting stations (traffic_cams_reg_check.Rmd). Walking time to green: continuous, min max capped at p98, in both cities (decided 19 November 2026; Klagenfurt previously used 4 classes). Malta green per person: log10 of m² per person (no offset), bounds = p2 and p98 of the log over eligible populated cells, zero green per person = 1 (highest priority), missing in unpopulated cells (green per person is undefined where nobody lives; those cells are scored on the other criteria under 4.2). The same normalisation applies to the ATGreen and step variants (decided 19 November 2026).

3.5 Walking time to green (both cities, decided 20 November 2026): our own routing, as for green per person: OpenStreetMap walking network with the pedestrian filter in `mcda/walk_filter.R` (keeps ways with foot = yes, designated or permissive, including shared foot and cycle paths; always drops foot = no, access = private and access = military), shortest paths at 5 km/h, ATGreen's network origin points (every 50 m) and cell assignment (mean over the points in the cell; connector to the nearest point within 200 m; otherwise missing). An origin point inside a green patch has time 0, and a cell assigned to such a point gets 0 (no connector walk); the same rule applies to the E2SFCA travel times. Green classes 14110, 14130, 31000, 40000, at least 500 m², in both cities (class 32000 excluded). Normalisation: min max capped at the p98 of eligible cells (Malta airport and port excluded; all cells in Klagenfurt). ATGreen's walking time (Valhalla in Malta, OSRM in Klagenfurt with class 32000) is a sensitivity analysis only (`priority_atg_walk`).

3.6 Street greenery (Malta), decided 23 November 2026, replaces `perc_tree` (Urban Atlas 2018 Street Tree Layer, about 90% of cells tied at zero because of its 500 m² minimum mapping unit):
- Source: Meta and WRI canopy height map v2 (1 m; imagery 9 July 2019 and 18 January 2020), `data/malta/canopy_meta/`.
- Indicator: `street_canopy_pct` = share of the street buffer covered by canopy of 3 m or more. Street buffer = 10 m each side of the centreline of kept OSM streets (primary, secondary, tertiary, residential, unclassified, living_street, pedestrian, trunk and their _link versions; service, track, footway, path, steps, cycleway excluded).
- Normalisation: cost criterion, 1 minus min max capped at p98 (linear; less canopy = higher priority), the same rule as every criterion that is not extremely skewed (skewness 2.4, against 16.9 for green per person, the only log transformed criterion). Decided 23 November 2026.
- Cells with no street buffer: not applicable, criterion score 0 (see 4.2).
- Justification of 10 m: measured street half width (centreline to facade, Microsoft Global ML Building Footprints): median 6.0 m in continuous urban fabric, 78% of sides within 10 m (90% within 15 m); residential streets median 6.4 m, 75% within 10 m.
- Sensitivity only: log10(street_canopy_pct + 1); 15 m buffer; 2 m and 5 m height; whole cell canopy; NA instead of 0 for cells with no street (option a); old Street Tree Layer. The Urban Atlas class rule (agricultural and open land not applicable) was dropped on 26 November 2026: eligibility of farmland is a question for the whole map, not for one criterion.

## 4. Priority score

4.1 Weighted linear combination with citizen weights.

4.2 Missing values (available weight rule): a cell is scored only if its available criteria carry at least 80% of the total weight; score = sum(w_i * s_i) / sum(w_i) over available criteria. Missing is missing: never set to 0 or to the maximum.

Not applicable is not missing: when a criterion's own definition does not apply to a cell, the criterion score is 0 (no need) and counts as available weight. Current case: street greenery in cells with no street within 10 m. Pending sensitivity (23 November 2026): green per person in unpopulated cells as not applicable (0) instead of missing, for consistency with street greenery.

4.3 Priority classes: quintiles within each city (Q5 = top priority). Quartiles belong to the HIA paper only.

## 5. Comparisons and sensitivity analyses

5.1 Rank agreement: Spearman (never Pearson), across scored cells. Also report among populated cells, with quintiles still computed over all scored cells.

5.2 Class agreement: percentage of the main map's top quintile cells that stay in the top quintile.

5.3 Sensitivity set: citizen vs equal weights; each weight ±20% (others rescaled to sum to 1); traffic variants: K2, K5, CAMS-REG vehicle km (log10 + 1), OpenTransportMap criterion; traffic excluded within leave one out; Klagenfurt raw median income; Malta green per person variants (3.3); Malta green per person = 0 (not applicable) in unpopulated cells instead of missing, consistent with the street greenery rule (4.2), scored set recomputed with the available weight rule (added 25 November 2026); leave one out (each criterion dropped in turn, other weights rescaled to sum to 1; in Klagenfurt air quality drops NO2 and PM2.5 together; replaces the "without green per person" check, 20 November 2026); Malta street greenery variants (3.6; the agricultural and open land class rule was dropped on 26 November 2026); shared criteria only (the five criteria common to both cities, weights rescaled to sum to 1); weights: median instead of mean percentage share per criterion, rescaled to sum to 100% (both cities; Klagenfurt air quality split equally between NO2 and PM2.5; same cells as the main score; `survey_allocation_style.Rmd`, added 25 November 2026).

5.4 Burden coincidence (`Burden_coincidence_random_weights.Rmd`, Step 3, cells in the top quintile of three or more criteria vs shuffled): Step 3 tie rule: fractional membership (exactly 20% per criterion); cells with score 0 never count as burdened (if the 20% boundary falls in the zero class, only the cells above it count, e.g. Klagenfurt traffic 13.6%); shuffle restricted to cells where each criterion is defined (decided 25 November 2026). Count = sum over cells of the probability of three or more burdens, memberships independent within a cell (Poisson binomial). Old tie rule (25% fallback) and shuffle across all scored cells are sensitivity rows.

## 6. Descriptive statistics

6.1 Populated cells only, median and IQR.

6.2 Concentrations in µg/m³ (NO2 and PM2.5 separately, never the composite). WHO 2021 guidelines as the single benchmark for both cities.

## 7. Number format

7.1 Percentages one decimal (78.0%), weights one decimal, Spearman three decimals (0.924), p values as p < 0.001 or two decimals.

7.2 Ranges written with "to", not a dash.

## 8. Figures

8.1 Style: same as the HIA paper (`R/theme_lancet.R`), 8 pt, 180 mm wide, PNG 300 dpi + editable PPTX. Font: Arial where installed; otherwise the same font as the HIA figures in both papers.

8.2 Maps: draw the grid as a raster (no polygon seams, no cell borders); study area outline 0.3 pt dark grey; internal boundaries 0.15 pt light grey (Malta local councils only; no internal boundaries in Klagenfurt); outside the study area white; one scale bar per figure; no north arrow; no plot titles; legends with units.

8.3 Criterion maps: keep each criterion's own colour palette with a continuous scale, including walking time; skewed variables capped at p98; legend limits computed over eligible cells only, as the score's bounds (25 November 2026); shared criteria use the same scale limits in both cities, except land surface temperature, which keeps its own scale per city (decided 19 November 2026). Each map shows the indicator exactly as the score reads it.

8.4 Priority maps: quintiles within each city; captions state that classes are not comparable between cities.

## 9. Reporting

9.1 Every run ends with a report: numbers, paths of new files, and any check that failed. Stop and report instead of guessing when an input or a rule is unclear.

9.2 Record each change of method in `mcda/CHANGELOG.md`.