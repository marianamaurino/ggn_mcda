# Read a citizen survey export (.xlsx, first sheet) for the MCDA and survey notebooks.
#
# Since 2026-11-06 the survey exports are .xlsx (Malta data/malta/maltasurvey_jun26.xlsx,
# Klagenfurt data/klagenfurt/klagenfurtsurvey_nov26.xlsx); the old .csv files were removed.
# This function returns what the notebooks expected from the old csv:
#   - first sheet only (other sheets are pivot tables, a drill-down and 2 test rows);
#   - empty trailing columns dropped;
#   - categories that Excel turned into date serials mapped back
#     ("1-5" -> 46143, "5-10" -> 46300 in resident; "2-4" -> 46114, "5-7" -> 46208 in visit frequency;
#      Excel read "a-b" as day a, month b of 2026);
#   - whole numbers stored as "1.0" written as "1";
#   - numeric columns (the budget allocations) converted to numbers;
#   - dot_names = TRUE gives read.csv style names ("age-group" -> "age.group").
#
# Usage: source(here::here("R/read_survey.R")); survey <- read_survey(here::here("data/malta/maltasurvey_jun26.xlsx"))

read_survey <- function(path, dot_names = FALSE) {
  excel_serials <- c("46143" = "1-5", "46300" = "5-10", "46114" = "2-4", "46208" = "5-7")

  d <- readxl::read_excel(path, sheet = 1, col_types = "text", .name_repair = "minimal")
  d <- d[, names(d) != "" & colSums(!is.na(d)) > 0, drop = FALSE]

  fix_text <- function(x) {
    x <- sub("^(-?[0-9]+)\\.0$", "\\1", x)          # "1.0" -> "1"
    hit <- x %in% names(excel_serials)
    x[hit] <- excel_serials[x[hit]]
    x
  }
  d <- dplyr::mutate(d, dplyr::across(dplyr::everything(), fix_text))
  d <- readr::type_convert(d, col_types = readr::cols(.default = readr::col_guess()))

  if (dot_names) names(d) <- make.names(names(d))
  d
}
