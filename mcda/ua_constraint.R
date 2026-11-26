# Constraint cells (spec 1.3, water added 25 November 2026): cells whose majority Urban Atlas class is
# airport (12400), port (12300) or water (50000) are not eligible for greening and are not scored.
# Malta: airport, port and water (Urban Atlas 2021). Klagenfurt: water only (Urban Atlas 2018, because the
# 2021 layer was not available on 25 November 2026; to be checked against 2021 when it can be downloaded).
# Sourced by both scoring notebooks. Instruction: mcda/Water_constraint_instructions.Rmd.
#
# Majority class = the Urban Atlas class with the largest total area in the cell (decided 25 November 2026, both
# cities, every constraint class; first class on ties). Until 25 November 2026 Malta used the class of the largest
# single polygon piece. In Malta the pieces are the Urban Atlas 2021 polygons intersected with the cell and are
# summed by class; in Klagenfurt the input is already a table of Urban Atlas 2018 area per class and cell.

library(dplyr)
library(sf)

CONSTRAINT_CODES <- list(Malta = c("12400", "12300", "50000"), Klagenfurt = c("50000"))
WATER_CODE <- "50000"

# Pieces from Urban Atlas polygons (Malta): one row per cell and intersected polygon piece
ua_pieces_from_polygons <- function(cells, id, ua_path, code_col = "code_2021") {
  ua <- st_read(ua_path, quiet = TRUE, wkt_filter = st_as_text(st_as_sfc(st_bbox(cells)))) %>%
    select(code = all_of(code_col)) %>%
    st_make_valid()
  st_intersection(cells %>% select(all_of(id)), ua) %>%
    mutate(area = as.numeric(st_area(.))) %>%
    st_drop_geometry() %>%
    transmute(id = .data[[id]], code = as.character(code), area)
}

# Pieces from a table of area per class and cell (Klagenfurt): columns id plus one column per class code
ua_pieces_from_table <- function(tab, id) {
  tab %>%
    select(-any_of("total_area")) %>%
    tidyr::pivot_longer(-all_of(id), names_to = "code", values_to = "area") %>%
    filter(area > 0) %>%
    transmute(id = .data[[id]], code = as.character(code), area)
}

# Majority class per cell (largest total area by class) and water share of the cell
ua_majority <- function(pieces, cell_area = 1e4) {
  maj <- pieces %>% group_by(id, code) %>% summarise(area = sum(area), .groups = "drop") %>%
    group_by(id) %>% slice_max(area, n = 1, with_ties = FALSE) %>% ungroup() %>%
    select(id, ua_code = code)
  wat <- pieces %>% group_by(id) %>% summarise(water_share = sum(area[code == WATER_CODE]) / cell_area, .groups = "drop")
  maj %>% left_join(wat, by = "id")
}

# Constraint flag for a vector of majority classes (NA class = no Urban Atlas data = not constrained)
ua_constrained <- function(ua_code, city) !is.na(ua_code) & ua_code %in% CONSTRAINT_CODES[[city]]
