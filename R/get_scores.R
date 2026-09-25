# data ingest
library(ffscrapr)
library(curl)
library(readr)
library(glue)

# data munging
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(purrr)

# data display and interaction
library(DT)

# get connection to Sleeper leagues
source("R/get_conn.R")

# get league names
df_league_names <- purrr::map(lts_conn, ~ ff_league(.x)) |>
  dplyr::bind_rows(.id = "league") |>
  dplyr::select(league, league_id, league_name)

v_rename <- setNames(df_league_names$league_name, df_league_names$league)

# get all franchise names and ids for all leagues
df_franchises <-
  purrr::map(lts_conn, ~ ffscrapr::ff_franchises(.x)) %>%
  dplyr::bind_rows(.id = "league") |> 
  dplyr::mutate(league = recode(league, !!!v_rename))

# this_week, update_week, survival_max_week and survival_source all come from
# R/config.R (sourced by R/get_conn.R above)
readr::write_lines(update_week, "./dat/update_week.txt")

# get all scores for each week
df_scores <- purrr::map(lts_conn, ~ ff_schedule(.x)) %>%
  dplyr::bind_rows(.id = "league") %>%
  # will only report the completed results week when the new week starts
  dplyr::filter(week <= this_week) %>%
  dplyr::mutate(league = recode(league, !!!v_rename),
                diff_score = abs(franchise_score - opponent_score),
                diff_rank = ceiling(rank(desc(diff_score), ties.method = "min")/2),
                total_score = franchise_score + opponent_score,
                total_rank = ceiling(rank(desc(total_score), ties.method = "min")/2)) %>%
  dplyr::left_join(df_franchises[, 1:4], by = c("league", "franchise_id")) %>%
  dplyr::left_join(
    df_franchises[, 1:4],
    by = c("league" = "league", "opponent_id" = "franchise_id"),
    suffix = c("", "_opponent")
  )

# write df_scores
readr::write_csv(df_scores, "dat/df_scores.csv")

# ---------------------------------------------------------------------------
# WEEKLY AWARDS
# Six categories, one table. Every category produces the same eight columns and
# differs only in how it picks the awardee row(s) within each week, so each one
# is just a label plus a `pick` function below.
#
# `v_category` sets the display order of the categories within a week.
# ---------------------------------------------------------------------------

v_category <-
  ordered(
    c(
      "Biggest Blowout",
      "Narrowest Win",
      "Fewest Points in Win",
      "Most Points in Loss",
      "Highest Score",
      "Lowest Score"
    )
  )

# NOTE: keep this list in alphabetical order by name. dplyr::arrange() is
# stable, so when two rows tie on Week + Category the order they were stacked
# in is what breaks the tie in the published table.
l_weekly_awards <- list(
  blowout = list(
    category = "Biggest Blowout",
    pick = function(df) dplyr::filter(df, result == "W", diff_score == max(diff_score))
  ),
  fewest_points_win = list(
    category = "Fewest Points in Win",
    pick = function(df) {
      df %>%
        dplyr::filter(result == "W") %>%
        dplyr::filter(franchise_score == min(franchise_score))
    }
  ),
  highest_score = list(
    category = "Highest Score",
    pick = function(df) dplyr::filter(df, franchise_score == max(franchise_score))
  ),
  lowest_score = list(
    category = "Lowest Score",
    pick = function(df) dplyr::filter(df, franchise_score == min(franchise_score))
  ),
  most_points_loss = list(
    category = "Most Points in Loss",
    pick = function(df) dplyr::filter(df, result == "L", opponent_score == max(opponent_score))
  ),
  narrow_win = list(
    category = "Narrowest Win",
    pick = function(df) dplyr::filter(df, result == "W", diff_score == min(diff_score))
  )
)

# apply one award definition to df_scores, week by week
get_weekly_award <- function(award) {
  pick <- award$pick

  df_scores %>%
    dplyr::group_by(week) %>%
    pick() %>%
    dplyr::ungroup() %>%
    dplyr::mutate(Category = factor(award$category, levels = levels(v_category), ordered = TRUE)) %>%
    dplyr::select(
      Week = week,
      Category,
      League = league,
      Awardee = franchise_name,
      Opponent = franchise_name_opponent,
      `Awardee Score` = franchise_score,
      `Opponent Score` = opponent_score,
      Difference = diff_score
    )
}

df_weekly <- l_weekly_awards %>%
  purrr::map(get_weekly_award) %>%
  dplyr::bind_rows() %>%
  dplyr::arrange(dplyr::desc(Week), factor(Category, levels = v_category))


# write df_weekly
readr::write_csv(df_weekly, "dat/df_weekly.csv")


# total points
df_total_points <- df_scores %>%
  dplyr::group_by(league, franchise_name) %>%
  dplyr::summarize(
    total_pts_for = sum(franchise_score, na.rm = TRUE),
    total_pts_against = sum(opponent_score, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::select(
    Team = franchise_name,
    `Total Points For` = total_pts_for,
    `Total Points Against` = total_pts_against,
    League = league
  ) %>%
  dplyr::arrange(desc(`Total Points For`), `Total Points Against`)


# write df_total_points
readr::write_csv(df_total_points, "dat/df_total_points.csv")


# ---------------------------------------------------------------------------
# SURVIVOR POOL
# Three teams are eliminated each week. `survival_max_week` and
# `survival_source` are set in R/config.R.
# ---------------------------------------------------------------------------

df_week_list <- df_scores %>%
  # only score COMPLETED weeks; including the in-progress week eliminates
  # teams on partial (often 0.00) scores
  dplyr::filter(week <= survival_max_week) %>%
  dplyr::arrange(week) %>%
  dplyr::group_by(league, franchise_id) %>%
  dplyr::mutate(cum_franchise_score = cumsum(franchise_score)) %>%
  dplyr::ungroup() %>%
  split(.$week)

# get max week in data, i.e., the current week
v_max_week <- length(df_week_list)

if (v_max_week < 1) {
  # before any week has finished there is nobody to eliminate yet; write empty
  # tables so the site still renders
  df_empty <- df_scores[0, ] %>%
    dplyr::mutate(cum_franchise_score = double())

  df_empty %>%
    dplyr::select(
      `Survival Week` = week,
      League = league,
      Team = franchise_name,
      Owner = user_name,
      Score = franchise_score,
      `Cumulative Score` = cum_franchise_score
    ) %>%
    readr::write_csv("dat/df_survived.csv")

  df_empty %>%
    dplyr::select(
      `Eliminated Week` = week,
      League = league,
      Team = franchise_name,
      Owner = user_name,
      Score = franchise_score,
      `Cumulative Score at Elimination` = cum_franchise_score
    ) %>%
    readr::write_csv("dat/df_eliminated.csv")
} else if (identical(survival_source, "manual")) {
  # hand-maintained tables win outright once Sleeper stops reporting scores
  # for non-bracket teams in the playoffs
  readr::read_csv("dat/df_survived_manual.csv", show_col_types = FALSE) %>%
    readr::write_csv("dat/df_survived.csv")

  readr::read_csv("dat/df_eliminated_manual.csv", show_col_types = FALSE) %>%
    readr::write_csv("dat/df_eliminated.csv")
} else {
  # get survival table
  df_survived <- df_week_list %>%
    purrr::accumulate(\(x, d) {
      d %>%
        dplyr::filter(franchise_name %in% x$franchise_name) %>%
        # to break ties, I add in a _very_ small portion of the cumulative franchise score
        # the effect is that any ties are broken using lowest cumulative score
        dplyr::slice_max(
          order_by = (franchise_score + .00001 * cum_franchise_score),
          n = -3,
          with_ties = FALSE
        )
    }, .init = df_week_list[[1]]) %>%
    tail(-1)

  # write df_survived
  df_survived %>%
    dplyr::bind_rows() %>%
    dplyr::select(
      `Survival Week` = week,
      League = league,
      Team = franchise_name,
      Owner = user_name,
      Score = franchise_score,
      `Cumulative Score` = cum_franchise_score
    ) %>%
    dplyr::arrange(desc(`Survival Week`), desc(Score)) %>%
    readr::write_csv(., "dat/df_survived.csv")

  # get eliminated table by anti-joining with survival table
  df_eliminated <-
    purrr::map2(.x = df_week_list, .y = df_survived, ~ dplyr::anti_join(.x, .y, by = c("league", "week", "franchise_id"))) %>%
    dplyr::bind_rows() %>%
    dplyr::group_by(league, franchise_id) %>%
    dplyr::filter(week == min(week)) %>%
    dplyr::ungroup() %>%
    dplyr::select(
      `Eliminated Week` = week,
      League = league,
      Team = franchise_name,
      Owner = user_name,
      Score = franchise_score,
      `Cumulative Score at Elimination` = cum_franchise_score
    ) %>%
    dplyr::arrange(desc(`Eliminated Week`), desc(Score))

  # write df_eliminated
  readr::write_csv(df_eliminated, "dat/df_eliminated.csv")
}
