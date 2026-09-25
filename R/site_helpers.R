# ---------------------------------------------------------------------------
# Shared table formatting for index.qmd.
#
# Every table on the site is a DT::datatable with the same look: no row names,
# a filter row on top, and CSV/Excel/PDF download buttons. Only the page size
# differs, so that is the only thing each chunk has to pass in.
# ---------------------------------------------------------------------------

lts_datatable <- function(df, page_length, length_menu) {
  DT::datatable(
    df,
    rownames = FALSE,
    filter = "top",
    extensions = "Buttons",
    options = list(
      pageLength = page_length,
      lengthMenu = length_menu,
      dom = "Bfrtpl",
      buttons = c("csv", "excel", "pdf")
    )
  )
}
