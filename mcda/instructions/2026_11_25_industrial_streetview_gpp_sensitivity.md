Before starting, save this whole instruction verbatim as mcda/instructions/2026_11_25_industrial_streetview_gpp_sensitivity.md (create the folder if needed).

Follow MCDA_paper_results_spec.md. Never use em dashes in any text you write (hyphens are fine).
For every comparison give both a figure and a table. Do not commit. Report first.
Use the current scores (after the K3 traffic switch and the water constraint of 25 November). Grids: Malta 10,657 cells by gid; Klagenfurt 12,418 cells by ID; stop if counts differ.

PART 0. One majority rule for both cities (this changes the scores; do it first)
 - My decision: majority class = the Urban Atlas class with the largest total area in the cell, in both cities and for every constraint class (airport 12400, port 12300, water 50000). Malta currently uses the class of the largest single polygon; switch it to largest total area in mcda/ua_constraint.R. Klagenfurt already uses largest total area (Urban Atlas 2018 class table).
 - Backups with the suffix _pre_majority, checksums in the CHANGELOG.
 - Rerun everything that depends on the scores (as in the water constraint instruction, step 4), including Step 3 and analyses A to D.
 - Report old vs new: constraint cell counts by class (expected Malta about 456 airport and port, 268 water), scored cells, Spearman, top quintile overlap, Step 3 main ratios.
 - Spec 1.3: state "majority class = class with the largest total area in the cell" and update counts. Spec 3.4: add "normalisation bounds are computed over eligible cells only (constraint cells excluded)".
 - criteria_maps_paper.R: compute legend limits over eligible cells only, so each map shows the indicator as the score reads it (spec 8.3). Re-run the criterion maps.

Then Parts A to E, on the new scores. Create a new notebook mcda/checks_industrial_streetview.Rmd for Parts A and B. Do not change any score file in Parts A and B.

PART A. Industrial cells (Malta; Klagenfurt too if there are any)
 - Industrial cell = majority class 12100 with the Part 0 rule (Klagenfurt from Urban Atlas 2018, as for water).
 - Per city: number of industrial cells; how many have no kept street within the cell (street greenery not applicable, score 0); how many of those have OSM service roads inside (roads inside estates); population.
 - Street greenery for industrial cells: distribution of street_canopy_pct where defined; and, for cells with only service roads, the canopy share of a 10 m buffer around those service roads (computed here only, as information).
 - Priority quintile distribution of industrial cells, current score vs a version (in memory only) where service roads count as streets for street greenery in industrial cells only. Spearman and top quintile overlap.
 - Map: industrial cells by quintile, with service roads drawn.
 - Report the numbers. Do not choose; I will decide.

PART B. Street View sample for street greenery (Malta)
 B1. Draw 30 cells at random (fixed seed) among scored Malta cells with a street buffer, stratified by street_canopy_pct: 10 cells at 0%; 10 cells between 0% and the median of cells above 0; 10 cells above the 80th percentile. Add 5 extra cells in upper Valletta with street_canopy_pct between 15 and 25%.
 B2. For each of the 35 cells, one image panel (PNG per cell and one combined PDF): left, the 1 m canopy (3 m or more) over an aerial or OSM basemap for the cell, with the 10 m street buffer and the cell outlined; right, a small locator map; title: gid, council, street_canopy_pct, stratum.
 B3. A CSV mcda/output/streetview_sample.csv with: gid, council, stratum, street_canopy_pct, centroid latitude and longitude (WGS 84), and a Google Street View link built as https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=LAT,LON. Add empty columns for me to fill: trees_visible (none, few, many), agrees_with_indicator (yes, partly, no), note.
 B4. Do not judge the images yourself. I will fill the CSV and then you summarise agreement by stratum.

PART C. Sensitivity: green per person "not applicable" in unpopulated cells (Malta)
 - Add to the sensitivity set (spec 5.3): green per person = 0 (not applicable, no need) in unpopulated cells instead of missing, consistent with the street greenery rule (spec 4.2). Everything else as in the main score.
 - Report: scored cells (main vs variant; cells newly scored because they now reach 80% of the weight), Spearman and top quintile overlap with the main score, top 5 councils, and a map of cells whose quintile changes by 2 or more.

PART D. Remove the 4 km/h walking speed sensitivity
 - Remove it from spec 5.3 and from any notebook that still computes it. Reason to record in the CHANGELOG: walking time is min max normalised, so a uniform change of speed rescales all times and leaves the criterion scores unchanged.

PART E. Confirm analyses A to D are on the final scores
 - Confirm that Burden_coincidence_random_weights.Rmd was re-knitted on the scores after Part 0 (file paths, md5 and dates of the scores it read).
 - Report its headline numbers per city: A (mean absolute Spearman between criteria, share of variance of PC1, Step 3 main ratio), B (median and 5th to 95th percentile of Spearman and top quintile overlap with equal weights over the 1,000 draws), C (the same with the five shared criteria only), D (share of scored cells and of residents in robust core, contested, rarely prioritized). Also citizen vs equal weights (Spearman, top quintile overlap).

Record everything in mcda/CHANGELOG.md and update "Last updated" in the spec.
