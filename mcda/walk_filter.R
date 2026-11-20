# Pedestrian filter for the OSM walking network, shared by mcda/malta_e2sfca_newpop.R and
# mcda/klagenfurt_e2sfca_newpop.R (2026-11-20).
#
# Before 2026-11-20 the filter followed OSMnx "walk" and dropped every highway=cycleway. In Klagenfurt
# this removed shared foot and cycle paths (highway=cycleway + foot=designated/yes), which OSRM's foot
# profile keeps: 188 of the 208 origin points where our time exceeded ATGreen's (OSRM) by >= 3 min.
#
# Rules (a way is kept if all hold):
#   1. highway not in WALK_HARD_DROP (never walkable, whatever the foot tag);
#   2. foot != "no";
#   3. access is not "private" or "military" (military dropped 2026-11-20, second run);
#   4. either foot is yes/designated/permissive (explicit pedestrian access), or the way is not a
#      cycleway, access != "no", service != "private" and area != "yes".

WALK_HARD_DROP <- c("motorway", "motorway_link", "construction", "proposed", "raceway", "bus_guideway",
                    "busway", "abandoned", "planned", "platform", "razed", "no")
FOOT_OK <- c("yes", "designated", "permissive")

walk_keep <- function(hw) {
  ne <- function(x, v) is.na(x) | x != v
  foot_ok <- !is.na(hw$foot) & hw$foot %in% FOOT_OK
  keep <- !is.na(hw$highway) & !(hw$highway %in% WALK_HARD_DROP) & ne(hw$foot, "no") & ne(hw$access, "private") &
    ne(hw$access, "military") & (foot_ok | (hw$highway != "cycleway" & ne(hw$access, "no") & ne(hw$service, "private") & ne(hw$area, "yes")))
  keep %in% TRUE   # ways without a highway tag are dropped (never NA)
}

# The filter before 2026-11-20, kept to report what changed
walk_keep_old <- function(hw) {
  ne <- function(x, v) is.na(x) | x != v
  !grepl(paste0("^(", paste(c(WALK_HARD_DROP, "cycleway"), collapse = "|"), ")$"), hw$highway) &
    ne(hw$foot, "no") & ne(hw$access, "private") & ne(hw$service, "private") & ne(hw$area, "yes")
}

# Tables of what is kept and dropped, by highway type and by foot x access tags
walk_filter_report <- function(hw, out_prefix) {
  d <- sf::st_drop_geometry(hw) %>%
    dplyr::mutate(k = walk_keep(hw), k_old = walk_keep_old(hw) %in% TRUE,
                  highway = tidyr::replace_na(highway, "(none)"),
                  foot = tidyr::replace_na(foot, "(none)"), access = tidyr::replace_na(access, "(none)"))
  by_hw <- d %>% dplyr::group_by(highway) %>%
    dplyr::summarise(ways = dplyr::n(), kept = sum(k), dropped = sum(!k),
                     kept_before_nov20 = sum(k_old), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(ways))
  by_tag <- d %>% dplyr::group_by(foot, access) %>%
    dplyr::summarise(ways = dplyr::n(), kept = sum(k), dropped = sum(!k),
                     kept_before_nov20 = sum(k_old), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(ways))
  readr::write_csv(by_hw, paste0(out_prefix, "_filter_by_highway.csv"))
  readr::write_csv(by_tag, paste0(out_prefix, "_filter_by_foot_access.csv"))
  stopifnot(!any(d$k & d$foot == "no"), !any(d$k & d$access %in% c("private", "military")))
  cat("walk filter: kept", sum(d$k), "of", nrow(d), "ways (before 2026-11-20:", sum(d$k_old), ")\n")
  invisible(list(by_highway = by_hw, by_tag = by_tag))
}

# Zero rule (2026-11-20, as ATGreen): an origin point inside a green patch has time 0 to that patch,
# and a connector cell assigned to such a point gets 0 (no connector walk).
# inside: logical matrix origin points x patches. Tp: origin points x patches (minutes).
apply_zero_rule <- function(Tp, inside) { Tp[inside] <- 0; Tp }
