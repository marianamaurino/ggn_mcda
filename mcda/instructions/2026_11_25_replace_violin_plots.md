Before starting, save this whole instruction verbatim as mcda/instructions/2026_11_25_replace_violin_plots.md (create the folder if needed).

Follow MCDA_paper_results_spec.md. Never use em dashes in any text you write (hyphens are fine). Do not commit. Report first.

In Burden_coincidence_random_weights.Rmd, replace every violin plot (section B, and section C if it has the same kind of figure) with histograms:
 - Two figures per section: (1) Spearman with the equal weights map, (2) top quintile overlap with the equal weights map (%).
 - In each figure, one histogram per city, stacked vertically (Klagenfurt above, Malta below), same x axis range for both, binwidth 0.01 for Spearman and 1 percentage point for overlap. Same city colours as now.
 - x axis title: "Agreement with the equal weights map (Spearman)" or "Top quintile cells shared with the equal weights map (%)". y axis title: "Number of random weight sets (of 1,000)". City name as panel label.
 - In each panel: a dashed vertical line at the median with its value written next to it, and a solid vertical line at the citizen weights value (Malta Spearman 0.956 and overlap 83.6%; Klagenfurt 0.977 and 92.0%; read them from the data, do not hardcode) labelled "Citizen weights".
 - Also report, per city, the percentile of the citizen weights value within the 1,000 random draws (e.g. "citizen weights agree with equal weights more than 97% of random weight sets").
 - Spec 8.1 style (theme_lancet, 8 pt, 180 mm wide, PNG 300 dpi and editable PPTX). Re-knit the notebook. Report the new figure paths and the percentiles.
