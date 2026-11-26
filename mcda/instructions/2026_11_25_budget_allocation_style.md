Before starting, save this whole instruction verbatim as mcda/instructions/2026_11_25_budget_allocation_style.md (create the folder if needed).

Follow MCDA_paper_results_spec.md. Never use em dashes in any text you write (hyphens are fine).
For every comparison give both a figure and a table. Do not change any score file. Do not commit. Report first.
Create a new notebook mcda/survey_allocation_style.Rmd. Use the same respondents as the weights (Malta n = 123; Klagenfurt n = 184 after excluding former residents); read n from the data.

Context: Malta respondents allocated a budget of 1,000 euros across 10 criteria; Klagenfurt respondents 1,000,000 euros across 6. Weights are percentage shares, so the scale does not matter mathematically, but the budget size may change how people allocate. Budget and city are confounded, so this is descriptive only.

PART 0. Survey interface
 - From the survey code or the raw data, report how allocations could be entered in each city (slider, free number, step size), whether the full budget had to be allocated, and the smallest non zero unit actually used. Report the number of distinct allocation values per city and how many respondents did not allocate the full budget.

PART A. Allocation style per city (table and figures)
 Per respondent, compute and then summarise per city (median and IQR, or %):
 1. Gave 0 to at least one criterion (% of respondents) and number of criteria with 0 (median).
 2. Highest share given to a single criterion (%).
 3. Round number heaping: % of non zero allocations that are multiples of 10% of the budget, and of 5% of the budget.
 4. Normalised entropy of the respondent's shares, H = minus sum of p log p divided by log(number of criteria): 1 = perfectly even, 0 = everything to one criterion. This makes 10 and 6 criteria comparable.
 5. Share of respondents who allocated exactly equal amounts to all criteria.
 Figures: histograms per city (stacked vertically, same x axis) of the highest share and of the normalised entropy; a bar chart of the distribution of allocation values (% of the budget) per city, to show heaping.
 Test the city difference for 2 and 4 with a Mann-Whitney test (report p as in spec 7.1), and say in the report that a difference cannot be attributed to the budget, because budget and city are confounded.

PART B. Sensitivity: median instead of mean weights (both cities)
 - Weights = median percentage share per criterion, rescaled to sum to 100%. Report them next to the mean weights.
 - Recompute the score with these weights (spec 4.2, same cells) and compare with the main citizen score: Spearman, top quintile overlap, cells changing quintile. Add the row "Weights: median instead of mean" to Table S6 for both cities.

Report all tables and figures, and record the new sensitivity row in mcda/CHANGELOG.md and spec 5.3.
