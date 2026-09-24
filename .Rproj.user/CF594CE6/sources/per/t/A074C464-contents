lts_conn <- c(
  "1264963268108111872",
  "1264964413060820992",
  "1264964517792591872",
  "1264964602135846912"
) %>%
  purrr::set_names("L1", "L2", "L3", "L4") %>%
  purrr::map(.x = .,
             ~ ffscrapr::ff_connect(
               league_id = .x,
               platform = "sleeper",
               season = 2025
             ))