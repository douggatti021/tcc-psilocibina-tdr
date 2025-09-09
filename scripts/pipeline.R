# scripts/pipeline.R
# Ponto de entrada do projeto: ajusta parâmetros, executa fluxo e gera saídas

suppressPackageStartupMessages({
  library(tidyverse)
  library(openxlsx)
})

source("scripts/setup.R")
# NÃO vamos depender de helpers.R enquanto depuramos
# source("scripts/helpers.R")

# ========= versão LOCAL e SEGURA de derive_ano (ignora colunas ausentes) =========
safe_derive_ano <- function(df) {
  get_year <- function(col) {
    if (col %in% names(df)) {
      suppressWarnings(as.integer(substr(as.character(df[[col]]), 1, 4)))
    } else {
      rep(NA_integer_, nrow(df))
    }
  }
  df %>% mutate(.ano = coalesce(
    get_year("ANO_CMPT"),
    get_year("MES_CMPT"),
    get_year("PA_CMP"),
    get_year("DTOBITO")
  ))
}

# ========= Parâmetros do estudo =========
anos_ini   <- 2015
anos_fim   <- 2024
ufs        <- NULL            # ex.: c("SP","RJ"); NULL = Brasil
write_csvs <- TRUE
write_xlsx <- TRUE
xlsx_path  <- file.path("resultados", "datasus_f32_f33_uf_ano.xlsx")

# ========= Funções de ingestão (mocks p/ teste local) =========
fetch_sih_mock <- function(ano, ufs = NULL) {
  base_ufs <- if (is.null(ufs)) c("SP","RJ","MG") else ufs
  tibble(
    UF         = base_ufs,
    DIAS       = sample(1:15, length(base_ufs), replace = TRUE),
    GASTO      = runif(length(base_ufs), 1e5, 5e5),
    DIAG_PRINC = sample(c("F320","F321","F330","F331"), length(base_ufs), TRUE),
    ANO_CMPT   = ano,
    MES_CMPT   = sprintf("%d%02d", ano, 1)   # <— compatível com safe_derive_ano
  )
}

fetch_sia_mock <- function(ano, ufs = NULL) {
  base_ufs <- if (is.null(ufs)) c("SP","RJ","MG") else ufs
  tibble(
    UF        = base_ufs,
    ATEND     = sample(50:300, length(base_ufs), TRUE),
    PA_CIDPRI = sample(c("F320","F330","F332"), length(base_ufs), TRUE),
    PA_CMP    = sprintf("%d%02d", ano, 1)
  )
}

fetch_sim_mock <- function(ano, ufs = NULL) {
  base_ufs <- if (is.null(ufs)) c("SP","RJ","MG") else ufs
  tibble(
    UF       = base_ufs,
    OBITOS   = sample(5:80, length(base_ufs), TRUE),
    CAUSABAS = sample(c("F320","F330"), length(base_ufs), TRUE),
    DTOBITO  = sprintf("%d-01-01", ano)
  )
}

anos <- seq.int(anos_ini, anos_fim)

# ========= SIH-RD =========
sih_raw <- purrr::map_dfr(anos, ~fetch_sih_mock(.x, ufs = ufs))
sih <- sih_raw %>%
  filter(startsWith(as.character(DIAG_PRINC), "F32") |
         startsWith(as.character(DIAG_PRINC), "F33")) %>%
  safe_derive_ano() %>%
  group_by(UF, .ano) %>%
  summarise(
    internacoes = n(),
    media_dias  = mean(DIAS, na.rm = TRUE),
    gasto_total = sum(GASTO, na.rm = TRUE),
    .groups = "drop"
  )

# ========= SIA-PA =========
sia_raw <- purrr::map_dfr(anos, ~fetch_sia_mock(.x, ufs = ufs))
sia <- sia_raw %>%
  filter(startsWith(as.character(PA_CIDPRI), "F32") |
         startsWith(as.character(PA_CIDPRI), "F33")) %>%
  safe_derive_ano() %>%
  group_by(UF, .ano) %>%
  summarise(atendimentos = sum(ATEND, na.rm = TRUE), .groups = "drop")

# ========= SIM-DO =========
sim_raw <- purrr::map_dfr(anos, ~fetch_sim_mock(.x, ufs = ufs))
sim <- sim_raw %>%
  filter(startsWith(as.character(CAUSABAS), "F32") |
         startsWith(as.character(CAUSABAS), "F33")) %>%
  safe_derive_ano() %>%
  group_by(UF, .ano) %>%
  summarise(obitos = sum(OBITOS, na.rm = TRUE), .groups = "drop")

# ========= Escrita das saídas =========
if (write_csvs) {
  write_csv(sih, "saida_dados/sih_internacoes.csv")
  write_csv(sia, "saida_dados/sia_atendimentos.csv")
  write_csv(sim, "saida_dados/sim_obitos.csv")
  message("CSVs gravados em 'saida_dados/'.")
}

if (write_xlsx) {
  wb <- createWorkbook()
  addWorksheet(wb, "SIH_internacoes"); writeData(wb, "SIH_internacoes", sih)
  addWorksheet(wb, "SIA_atendimentos"); writeData(wb, "SIA_atendimentos", sia)
  addWorksheet(wb, "SIM_obitos");      writeData(wb, "SIM_obitos", sim)
  saveWorkbook(wb, xlsx_path, overwrite = TRUE)
  message("Planilha gerada: ", xlsx_path)
}

message("Pipeline finalizado com sucesso.")
