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

# current week
this_week <- difftime(lubridate::now(), lubridate::ymd("2025-09-03"), units = "weeks") %>% ceiling() %>% as.integer()

# week number for update
# update_week <- difftime(
#   lubridate::now(tz = "America/New_York"),
#   # TUE before the first THU night game
#   # so it says results are final for week just completed on 1130a scheduled run
#   lubridate::ymd_hms("2025-09-02 11:00:00", tz = "America/New_York"),
#   units = "weeks"
# ) %>%
#   floor() %>%  as.integer()
update_week <- 17
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

# define weekly categories so we can sort by ordered list in full df_weekly later
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

df_weekly_blowout <- df_scores %>%
  dplyr::group_by(week) %>%
  dplyr::filter(result == "W", diff_score == max(diff_score)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(Category = v_category[1]) %>%
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

df_weekly_narrow_win <- df_scores %>%
  dplyr::group_by(week) %>%
  dplyr::filter(result == "W", diff_score == min(diff_score)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(Category = v_category[2]) %>%
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

df_weekly_fewest_points_win <- df_scores %>%
  dplyr::group_by(week) %>%
  dplyr::filter(result == "W") %>%
  dplyr::filter(franchise_score == min(franchise_score)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(Category = v_category[3]) %>%
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

df_weekly_most_points_loss <- df_scores %>%
  dplyr::group_by(week) %>%
  dplyr::filter(result == "L", opponent_score == max(opponent_score)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(Category = v_category[4]) %>%
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

df_weekly_highest_score <- df_scores %>%
  dplyr::group_by(week) %>%
  dplyr::filter(franchise_score == max(franchise_score)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(Category = v_category[5]) %>%
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

df_weekly_lowest_score <- df_scores %>%
  dplyr::group_by(week) %>%
  dplyr::filter(franchise_score == min(franchise_score)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(Category = v_category[6]) %>%
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


# collect weekly categories
v_weekly_dfs <- ls(pattern = "df_weekly_")

df_weekly <- mget(v_weekly_dfs) %>%
  purrr::set_names(nm = v_weekly_dfs) %>%
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


# # playoffs
# v_bracket <- rep(c("winners_bracket", "losers_bracket"), 5)
# 
# v_league_id <- rep(unlist(purrr::map(lts_conn, "league_id")), 2) %>% sort()
# 
# v_query <- glue::glue("league/{v_league_id}/{v_bracket}")
# 
# v_query_string <- purrr::map(v_query, ~rep(.x, 4)) %>% unlist(.)
# 
# df_playoffs <- purrr::map(v_query, ~ffscrapr::sleeper_getendpoint(.x)) %>% 
#   purrr::map(., `[`, c("content", "query")) %>%
#   # purrr::set_names(purrr::map(., "query")) %>% 
#   dplyr::bind_rows(.id = "league_id") %>% 
#   dplyr::mutate(league = names(v_league_id[as.numeric(league_id)]),
#     league_id = v_league_id[as.numeric(league_id)]) %>% 
#   tidyr::unnest_wider(content)  %>% 
#   tidyr::unnest_wider(t1_from, names_sep = "_")  %>%
#   tidyr::unnest_wider(t2_from, names_sep = "_")



# survived teams
df_week_list <- df_scores %>%
  # hardcode until we resolve the playoff score reporting
  dplyr::filter(week < 15) %>%
  # dplyr::filter(week <= update_week) %>%
  dplyr::arrange(week) %>%
  dplyr::group_by(league, franchise_id) %>%
  dplyr::mutate(cum_franchise_score = cumsum(franchise_score)) %>%
  dplyr::ungroup() %>%
  split(.$week)

# get max week in data, i.e., the current week
v_max_week <- length(df_week_list)


# # get manual survival table
df_survived_manual <- readr::read_csv("dat/df_survived_manual.csv")

# # get survival table for wk 1-13
# df_survived <- df_week_list %>%
#   purrr::accumulate(\(x, d) {
#     d %>%
#       dplyr::filter(franchise_name %in% x$franchise_name) %>%
#       # to break ties, I add in a _very_ small portion of the cumulative franchise score
#       # the effect is that any ties are broken using lowest cumulative score
#       dplyr::slice_max(
#         order_by = (franchise_score + .00001 * cum_franchise_score),
#         n = -3,
#         with_ties = FALSE
#       )
#   }, .init = df_week_list$`1`) %>% 
#   tail(-1)
# 
# # write df_survived
# df_survived %>%
#   dplyr::bind_rows() %>%
#   dplyr::select(
#     `Survival Week` = week,
#     League = league,
#     Team = franchise_name,
#     Owner = user_name,
#     Score = franchise_score,
#     `Cumulative Score` = cum_franchise_score
#   ) %>%
#   # dplyr::bind_rows(df_survived_manual) %>%
#   dplyr::arrange(desc(`Survival Week`), desc(Score)) %>%
#   readr::write_csv(., "dat/df_survived.csv")


# get manual eliminated table
df_eliminated_manual <- readr::read_csv("dat/df_eliminated_manual.csv")

# # get eliminated table by anti-joining with survival table
# df_eliminated <-
#   purrr::map2(.x = df_week_list, .y = df_survived, ~ dplyr::anti_join(.x, .y, by = c("league", "week", "franchise_id"))) %>%
#   dplyr::bind_rows() %>%
#   dplyr::group_by(league, franchise_id) %>%
#   dplyr::filter(week == min(week)) %>%
#   dplyr::ungroup() %>%
#   dplyr::select(
#     `Eliminated Week` = week,
#     League = league,
#     Team = franchise_name,
#     Owner = user_name,
#     Score = franchise_score,
#     `Cumulative Score at Elimination` = cum_franchise_score
#   ) %>% 
#   # dplyr::bind_rows(df_eliminated_manual) %>%
#   dplyr::arrange(desc(`Eliminated Week`), desc(Score))
#   
# 
# # write df_eliminated
# readr::write_csv(df_eliminated, "dat/df_eliminated.csv")
