# Traffic criterion (spec 3.4, decided 2026-11-24): OSM road type in three classes (K3), both cities.
# Sourced by mcda/Malta_MCDA_260702_realloc.Rmd and mcda/Klagenfurt_MCDA_260520.Rmd; one function for both.
#
# Roads: the walking network OSM extracts (own_routing/osm_highways_raw.gpkg; Malta downloaded 5 November
# 2026, Klagenfurt 11 November 2026), clipped to the study area. Kept classes: motorway, trunk, primary,
# secondary, tertiary (each _link takes its parent class), unclassified, residential, living_street.
# Tunnels excluded: ways with any tunnel value other than "no", or covered = "yes". The extracts have no
# tunnel or covered column, so the tags come from an Overpass query of 24 November 2026 for the same
# bounding boxes (own_routing/osm_tunnel_covered_tags_2026-11-24.json), joined by OSM way id.
# Each cell takes the class of the highest kept road with at least 10 m inside it.
# K3: main (motorway, trunk, primary) = 1; distributor (secondary, tertiary) = 0.5; local (unclassified,
# residential, living_street) or no kept road = 0. Sensitivity: K2 and K5 (same tunnel rule). No missing values.
# Exploration and candidate comparison: mcda/traffic_road_type.Rmd.

suppressPackageStartupMessages({ library(sf); library(dplyr) })

RT_CLASSES <- c("motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street")
RT_SCORES <- tibble::tibble(
  class = c(RT_CLASSES, "no road"),
  K2 = c(1, 1, 1, 1, 0, 0, 0, 0, 0),
  K3 = c(1, 1, 1, 0.5, 0.5, 0, 0, 0, 0),
  K5 = c(1, 1, 0.75, 0.5, 0.25, 0, 0, 0, 0))

read_tunnel_tags <- function(tags_path) {
  el <- jsonlite::fromJSON(tags_path, simplifyVector = FALSE)$elements
  tg <- function(e, k) if (is.null(e$tags[[k]])) NA_character_ else e$tags[[k]]
  tibble::tibble(osm_id = as.character(sapply(el, function(e) e$id)),
                 tunnel = sapply(el, tg, "tunnel"), covered = sapply(el, tg, "covered")) %>%
    mutate(drop = (!is.na(tunnel) & tunnel != "no") | (!is.na(covered) & covered == "yes"))
}

# grid: sf with an id column; boundary: sf/sfc of the study area. Returns a list:
#   cells    : one row per grid cell (id, highest class, K2, K3, K5, and K3 without the tunnel rule)
#   tunnels  : dropped road pieces inside the study area (sf, for the report and the map)
road_type_k3 <- function(grid, id_col, osm_path, tags_path, boundary, min_m = 10, crs = 3035) {
  grid <- st_transform(grid, crs)
  area <- st_union(st_transform(st_geometry(boundary), crs))
  tags <- read_tunnel_tags(tags_path)
  roads <- st_read(osm_path, quiet = TRUE) %>% st_transform(crs) %>%
    mutate(osm_id = as.character(osm_id), class = sub("_link$", "", highway)) %>%
    filter(class %in% RT_CLASSES) %>%
    left_join(tags %>% select(osm_id, tunnel, covered, tunnel_drop = drop), by = "osm_id") %>%
    mutate(tunnel_drop = coalesce(tunnel_drop, FALSE))
  roads <- suppressWarnings(st_intersection(roads, area)) %>% st_collection_extract("LINESTRING")
  g <- grid %>% transmute(cell = as.character(.data[[id_col]]))
  pieces <- suppressWarnings(st_intersection(roads %>% select(osm_id, class, name, tunnel_drop), g)) %>%
    st_collection_extract("LINESTRING") %>% mutate(m = as.numeric(st_length(.))) %>% st_drop_geometry()
  highest <- function(p) p %>% group_by(cell, class) %>% summarise(m = sum(m), .groups = "drop") %>%
    filter(m >= min_m) %>% group_by(cell) %>% summarise(rank = min(match(class, RT_CLASSES)), .groups = "drop") %>%
    transmute(cell, class = RT_CLASSES[rank])
  h_new <- highest(pieces %>% filter(!tunnel_drop))
  h_all <- highest(pieces)
  cells <- st_drop_geometry(g) %>%
    left_join(h_new, by = "cell") %>% mutate(class = coalesce(class, "no road")) %>%
    left_join(RT_SCORES, by = "class") %>%
    left_join(h_all %>% rename(class_with_tunnels = class), by = "cell") %>%
    mutate(class_with_tunnels = coalesce(class_with_tunnels, "no road"),
           K3_with_tunnels = RT_SCORES$K3[match(class_with_tunnels, RT_SCORES$class)]) %>%
    rename(road_class = class)
  stopifnot(nrow(cells) == nrow(grid), !anyNA(cells$K3))
  names(cells)[1] <- id_col
  tunnels <- roads %>% filter(tunnel_drop) %>% mutate(km = as.numeric(st_length(.)) / 1000) %>%
    select(osm_id, class, name, tunnel, covered, km)
  list(cells = cells, tunnels = tunnels)
}
