# scripts/helpers.R
# Funções utilitárias usadas pela pipeline

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
})

# starts_with_any: testa se x começa com qualquer prefixo de 'prefixes'
starts_with_any <- function(x, prefixes) {
  if (length(prefixes) == 0) return(rep(FALSE, length(x)))
  Reduce(`|`, lapply(prefixes, function(p) startsWith(as.character(x), p)))
}

# Função auxiliar: extrai ano (YYYY) de uma coluna se ela existir; senão devolve NAs
.year_from_col <- function(df, col) {
  if (col %in% names(df)) {
    suppressWarnings(as.integer(substr(as.character(df[[col]]), 1, 4)))
  } else {
    rep(NA_integer_, nrow(df))
  }
}

# derive_ano: cria coluna .ano pegando o 1º ano disponível entre várias colunas
derive_ano <- function(df) {
  y1 <- .year_from_col(df, "ANO_CMPT")
  y2 <- .year_from_col(df, "MES_CMPT")
  y3 <- .year_from_col(df, "PA_CMP")
  y4 <- .year_from_col(df, "DTOBITO")
  df %>%
    mutate(.ano = coalesce(y1, y2, y3, y4))
}

# fetch_by_years: aplica uma função de busca/ingestão ano a ano e concatena
fetch_by_years <- function(anos, fetch_fun, ufs = NULL) {
  map_dfr(anos, ~fetch_fun(.x, ufs = ufs))
}

# (stub) muni_to_uf_sigla: mantém UF se já existir; caso contrário preenche NA
muni_to_uf_sigla <- function(cod_mun, fallback_uf = NA_character_) {
  rep(fallback_uf, length(cod_mun))
}
