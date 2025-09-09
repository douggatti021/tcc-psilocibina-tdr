
# Funções auxiliares (preencher conforme necessidade)

starts_with_any <- function(x, prefixes) {
  any(startsWith(x, prefixes))
}

derive_ano <- function(df, coluna = NULL) {
  # Se não houver coluna de ano, tenta inferir
  if (is.null(coluna) || !coluna %in% names(df)) {
    if ("DT_INTER" %in% names(df)) {
      df$ano <- lubridate::year(lubridate::ymd(df$DT_INTER))
    } else if ("ANO" %in% names(df)) {
      df$ano <- df$ANO
    } else {
      df$ano <- NA_integer_
    }
  } else {
    df$ano <- df[[coluna]]
  }
  df
}

