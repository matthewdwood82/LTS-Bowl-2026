# ---------------------------------------------------------------------------
# Packages used by both R/get_scores.R and index.qmd.
# Add a package here once rather than in each file, and remember to run
# renv::snapshot() so it lands in renv.lock.
# ---------------------------------------------------------------------------

# data ingest
library(ffscrapr)
library(curl)
library(readr)

# data munging
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(purrr)

# data display and interaction
library(DT)
