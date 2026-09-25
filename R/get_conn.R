lts_conn <- c(
  "1384249414998052864",
  "1386830574496284672",
  "1386831161682038784",
  "1386831051346698240"
) %>%
  purrr::set_names("L1", "L2", "L3", "L4") %>%
  purrr::map(.x = .,
             ~ ffscrapr::ff_connect(
               league_id = .x,
               platform = "sleeper",
               season = 2026
             ))