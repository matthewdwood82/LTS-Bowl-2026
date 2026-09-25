# Living the Stream Bowl — scoring site

Quarto + R site that pulls four Sleeper leagues via
[`ffscrapr`](https://ffscrapr.ffverse.com/) and publishes weekly awards, total
points, all results and the survivor pool to
<https://matthewdwood82.github.io/LTS-Bowl-2026/>.

## Annual rollover checklist

Everything season-specific lives in **`R/config.R`**. To roll the site forward:

1. Create the new repo from last year's (e.g. `LTS-Bowl-2026` → `LTS-Bowl-2027`).
2. Edit `R/config.R` only:
   - `v_league_ids` — this year's four Sleeper league IDs, `L1`..`L4`.
   - `season` — the NFL season year.
   - `season_anchor` — `season_start_date` from
     <https://api.sleeper.app/v1/state/nfl> (the Wednesday before the Thursday
     opener).
   - `playoff_week_start` — first week of the Sleeper playoff bracket.
3. Make sure the three in-season toggles at the bottom of `R/config.R` are back
   in their *regular season* position (computed `update_week`,
   `survival_max_week <- update_week`, `survival_source <- "auto"`).
4. Update the bylaws link and the LM Discord links in `index.qmd`.
5. Uncomment the `schedule:` block in `.github/workflows/update-scores.yml` if
   you commented it out at the end of last season.
6. In repo Settings → Pages, confirm the source is the `gh-pages` branch.

## In-season toggles

`R/config.R` has three comment/uncomment pairs. Flip them as the season moves
from regular season → playoffs → LTS Bowl; each one is documented in place.
Nothing else should need editing mid-season.

## How it runs

Two GitHub Actions workflows, no local R required:

| Workflow | Trigger | What it does |
| --- | --- | --- |
| **Update Scores** (`update-scores.yml`) | Tue 11:30a ET cron, push to `main`, manual | Runs `R/get_scores.R`, then commits the regenerated `dat/*.csv` back to the branch |
| **Quarto Publish** (`quarto-publish.yml`) | Daily 4a ET, Tue 12p ET, push to `main`, manual | Renders `index.qmd` and publishes it to the `gh-pages` branch |

The rendered `index.html` is **not** committed to `main` — GitHub Pages serves
it from `gh-pages`, which Quarto Publish writes. It is gitignored so local
renders don't show up as changes.

The `dat/*.csv` files **are** committed on purpose. They are the only thing the
Quarto render reads, which keeps rendering fast and, more importantly, keeps
the published site working even when Sleeper's API is slow or down. Update
Scores is the only thing that should write them; don't hand-edit them. The two
exceptions are `dat/df_survived_manual.csv` and `dat/df_eliminated_manual.csv`,
which you maintain by hand once Sleeper stops reporting scores for non-bracket
teams in the playoffs (see the `survival_source` toggle).

## Layout

```
R/config.R         season settings + in-season toggles  <- the file you edit
R/libraries.R      shared library() preamble
R/get_conn.R       ffscrapr connections to the four leagues
R/get_scores.R     the whole pipeline; writes dat/*.csv
R/site_helpers.R   lts_datatable(), shared table formatting for index.qmd
index.qmd          the site
dat/*.csv          generated data, committed (see above)
custom.scss        theme
```

## Working locally

Dependencies are pinned with [renv](https://rstudio.github.io/renv/):

```r
renv::restore()        # install the pinned package versions
source("R/get_scores.R")  # refresh dat/*.csv
quarto::quarto_render("index.qmd")
```

If you add a package, add it to `R/libraries.R` and run `renv::snapshot()` so
the CI runners install it too.
