# scripts/helpers.R

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
})

# starts_with_any: testa se x começa com qualquer prefixo
starts_with_any <- function(x, prefixes) {
  if (length(prefixes) == 0) return(rep(FALSE, length(x)))
  Reduce(`|`, lapply(prefixes, function(p) startsWith(as.character(x), p)))
}

# função auxiliar interna: extrai ano se coluna existir
.year_from_col <- function(df, col) {
  if (col %in% names(df)) {
    suppressWarnings(as.integer(substr(as.character(df[[col]]), 1, 4)))
  } else {
    rep(NA_integer_, nrow(df))
  }
}

# derive_ano: cria coluna .ano com o 1º ano válido
derive_ano <- function(df) {
  y1 <- .year_from_col(df, "ANO_CMPT")
  y2 <- .year_from_col(df, "MES_CMPT")
  y3 <- .year_from_col(df, "PA_CMP")
  y4 <- .year_from_col(df, "DTOBITO")
  df %>% mutate(.ano = coalesce(y1, y2, y3, y4))
  cols <- c("ANO_CMPT", "MES_CMPT", "PA_CMP", "DTOBITO")
  anos <- map(cols, ~ .year_from_col(df, .x))
  df %>% mutate(.ano = Reduce(coalesce, anos))
}

# fetch_by_years
fetch_by_years <- function(anos, fetch_fun, ufs = NULL) {
  map_dfr(anos, ~fetch_fun(.x, ufs = ufs))
}
