# scripts/helpers.R
suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(readr)
  library(tidyr)
  library(purrr)
})

# Identifica se um texto começa com QUALQUER um dos prefixos fornecidos
starts_with_any <- function(x, prefixes) {
  patt <- paste0("^(", paste0(prefixes, collapse="|"), ")")
  str_detect(x, regex(patt, ignore_case = TRUE))
}

# Extrai "ano" a partir de várias colunas possíveis (robusto a formatos comuns)
derive_ano <- function(df, cols = c("ANO_CMPT","MES_CMPT","PA_CMP","DTOBITO")) {
  df %>%
    mutate(
      .ano = coalesce(
        suppressWarnings(as.integer(.data$ANO_CMPT)),
        suppressWarnings(as.integer(substr(.data$MES_CMPT %||% "", 1, 4))),
        suppressWarnings(as.integer(substr(.data$PA_CMP   %||% "", 1, 4))),
        suppressWarnings(year(ymd(.data$DTOBITO %||% NA_character_)))
      )
    )
}

# (stub) Converte código IBGE (7 dígitos) para UF; preencher depois com tabela IBGE
muni_to_uf_sigla <- function(cod_mun) {
  # TODO: trocar por join com tabela oficial do IBGE
  rep(NA_character_, length(cod_mun))
}

# Função genérica para baixar e empilhar por anos (você pluga a função de download)
fetch_by_years <- function(anos, fetch_fun, ..., sleep = 0) {
  purrr::map_dfr(anos, function(a) {
    message("Baixando ano: ", a)
    Sys.sleep(sleep)
    fetch_fun(ano = a, ...) %>% mutate(.ano_ref = a)
  })
}
