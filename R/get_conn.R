# season-specific settings live in R/config.R -- edit that file, not this one
source("R/config.R")

lts_conn <- v_league_ids %>%
  purrr::map(.x = .,
             ~ ffscrapr::ff_connect(
               league_id = .x,
               platform = "sleeper",
               season = season
             ))
