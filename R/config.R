# ---------------------------------------------------------------------------
# SEASON CONFIG -- this is the only file you should need to edit each season.
#
# 1. Update `v_league_ids` with this year's Sleeper league IDs.
# 2. Update `season` and `season_anchor` for the new calendar.
# 3. Flip the commented/uncommented toggles at the bottom as the season moves
#    from regular season -> playoffs -> LTS Bowl.
# ---------------------------------------------------------------------------

# --- league IDs ------------------------------------------------------------
# Sleeper league IDs, in L1..L4 order. Grab them from the league URL:
# https://sleeper.com/leagues/<league_id>
v_league_ids <- c(
  L1 = "1384249414998052864",
  L2 = "1386830574496284672",
  L3 = "1386831161682038784",
  L4 = "1386831051346698240"
)

# --- season calendar -------------------------------------------------------
# NFL season year, used for ffscrapr connections and scoring history.
season <- 2026

# The Wednesday before the first Thursday night game, i.e. the day scoring
# week 1 starts counting from. This is exactly what Sleeper reports as
# `season_start_date`, so you can copy it straight from:
#   curl -s https://api.sleeper.app/v1/state/nfl
# (2025 used 2025-09-03, the Wed before the Thu 2025-09-04 opener.)
season_anchor <- lubridate::ymd("2026-09-09")

# First week of the Sleeper playoff bracket. Sleeper stops reporting scores for
# teams outside the champion/toilet brackets from here on, so the survivor pool
# has to fall back to manual entry at this point.
playoff_week_start <- 15

# --- derived (no need to edit) ---------------------------------------------
# Upper bound on weeks that may have results.
this_week <- difftime(lubridate::now(), season_anchor, units = "weeks") |>
  ceiling() |>
  as.integer()

# The TUE 11:00a ET before the first THU night game. update_week floors from
# here, so the TUE 11:30a scheduled run reports the week that just finished as
# final -- and, importantly, does NOT call a week final on Monday while MNF is
# still being played.
week_zero <- lubridate::ymd_hms(
  paste(season_anchor - lubridate::days(1), "11:00:00"),
  tz = "America/New_York"
)

# ---------------------------------------------------------------------------
# IN-SEASON TOGGLES
# Comment/uncomment one line of each pair as the season progresses.
# ---------------------------------------------------------------------------

# (1) WEEK REPORTED AS FINAL ON THE SITE
# Regular season: leave the computed version uncommented.
# End of year: comment it out and hardcode the last completed week instead.
update_week <- difftime(lubridate::now(tz = "America/New_York"), week_zero, units = "weeks") |>
  floor() |>
  as.integer()
# update_week <- 17

# (2) SURVIVOR POOL CUTOFF WEEK
# Only score the pool through the last COMPLETED week. Scoring the in-progress
# week eliminates teams on partial (often 0.00) scores.
# Playoffs: freeze before `playoff_week_start`, because Sleeper stops reporting
# scores for non-bracket teams, and fill the rest in by hand.
survival_max_week <- update_week
# survival_max_week <- playoff_week_start - 1

# (3) SURVIVOR POOL SOURCE
# "auto"   -> compute dat/df_survived.csv and dat/df_eliminated.csv from Sleeper.
# "manual" -> use the hand-maintained dat/*_manual.csv files instead (switch to
#             this once the playoffs break Sleeper's score reporting).
survival_source <- "auto"
# survival_source <- "manual"
