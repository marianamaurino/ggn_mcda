# Instruction: per criterion maps for the MCDA paper (17 November 2026)

Follow `MCDA_paper_results_spec.md` (sections 1, 3 and 8 apply here). Do not change data or the score.

Existing maps (March 2026): Malta 01 population to 09 recreation; Klagenfurt 01 population to 10 recreation. Restyle them; regenerate only where stated.

## 0. Checks before plotting

a. Each existing map uses the current grid (Malta 10,657 cells, Klagenfurt 12,751) and the exact layer the score reads. List any mismatch.
b. Malta street greenery: which layer does the score read (tree fraction per cell, or tree cover restricted to streets) and from which source file?
c. Recreation (both cities): does the score use distance to the nearest facility or facility area? The current Malta map shows area (m²), but Methods says distance.

## 1. Content

a. Regenerate: Malta population (`pop_reallocated_nso`); Malta green proximity (walking time) and green per person (ATGreen Gaussian, as in the score); Klagenfurt air quality composite; Klagenfurt income; recreation in both cities as the indicator the score uses (0c).
b. One multi panel figure per city with only the criteria in that city's score plus population (Malta 11 panels, Klagenfurt 7). Panels labelled "A  Population", "B  Urban heat", and so on, in the order of spec 3.1 and 3.2.
c. Supplementary figure: Klagenfurt NO2 and PM2.5 separately (µg/m³).
d. Also save each panel as its own PNG, for checking.

## 2. Style (spec 8.2 and 8.3, plus)

a. Keep each map's current colour palette, with a continuous scale. Walking time stays categorical (0 to 5, 5 to 10, 10 to 15, over 15 min).
b. Population: same blue palette, starting from a slightly darker light tone, capped at p98, so populated areas read clearly.
c. Recreation: zero and low values clearly distinguishable from each other.
d. Shared criteria (LST, NO2 or air quality, distance to blue space) use the same scale limits in both cities.

## 3. Report

Paths of all new figures; scale limits used per panel; answers to 0a, 0b and 0c. Stop and report if any check in step 0 fails before plotting the affected panel.