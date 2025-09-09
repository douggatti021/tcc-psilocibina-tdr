# scripts/pipeline.R
# Ponto de entrada do projeto: ajusta parâmetros, executa fluxo e gera saídas

suppressPackageStartupMessages({
  library(tidyverse)
  library(openxlsx)
})

source("scripts/setup.R")
source("scripts/helpers.R")

# ========= Parâmetros do estudo =========
anos_ini   <- 2015
anos_fim   <- 2024
ufs        <- NULL            # ex.: c("SP","RJ") para filtrar; NULL = Brasil
write_csvs <- TRUE
write_xlsx <- TRUE
xlsx_path  <- file.path("resultados", "datasus_f32_f33_uf_ano.xlsx")

# ========= Funções de ingestão (mocks para teste) =========
# Troque depois por microdatasus real

fetch_sih_mock <- function(ano, ufs = NULL) {
  base_ufs <- if (is.null(ufs)) c("SP","RJ","MG") else ufs
  tibble(
    UF         = base_ufs,
    DIAS       = sample(1:15, length(base_ufs), replace = TRUE),
    GASTO      = runif(length(base_ufs), 1e5, 5e5),
    DIAG_PRINC = sample(c("F320","F321","F330","F331"),
                        size = length(base_ufs), replace = TRUE),
    ANO_CMPT   = ano,
    MES_CMPT   = paste0(ano, "01")  # <- adicionado para compatibilidade com derive_ano()
  )
}

fetch_sia_mock <- function(ano, ufs = NULL) {
  base_ufs <- if (is.null(ufs)) c("SP","RJ","MG") else ufs
  tibble(
    UF        = base_ufs,
    ATEND     = sample(50:300, length(base_ufs), replace = TRUE),
    PA_CIDPRI = sample(c("F320","F330","F332"),
                       size = length(base_ufs), replace = TRUE),
    PA_CMP    = paste0(ano, "01")
  )
}

fetch_sim_mock <- function(ano, ufs = NULL) {
  base_ufs <- if (is.null(ufs)) c("SP","RJ","MG") else ufs
  tibble(
    UF       = base_ufs,
    OBITOS   = sample(5:80, length(base_ufs), replace = TRUE),
    CAUSABAS = sample(c("F320","F330"),
                      size = length(base_ufs), replace = TRUE),
    DTOBITO  = paste0(ano, "-01-01")
  )
}

anos <- seq.int(anos_ini, anos_fim)

# ========= SIH-RD =========
sih_raw <- fetch_by_years(anos, fetch_sih_mock, ufs = ufs)
sih <- sih_raw %>%
  filter(starts_with_any(DIAG_PRINC, c("F32","F33"))) %>%
  derive_ano() %>%
  group_by(UF, .ano) %>%
  summarise(
    internacoes = n(),
    media_dias  = mean(DIAS, na.rm = TRUE),
    gasto_total = sum(GASTO, na.rm = TRUE),
    .groups = "drop"
  )

# ========= SIA-PA =========
sia_raw <- fetch_by_years(anos, fetch_sia_mock, ufs = ufs)
sia <- sia_raw %>%
  filter(starts_with_any(PA_CIDPRI, c("F32","F33"))) %>%
  derive_ano() %>%
  group_by(UF, .ano) %>%
  summarise(
    atendimentos = sum(ATEND, na.rm = TRUE),
    .groups = "drop"
  )

# ========= SIM-DO =========
sim_raw <- fetch_by_years(anos, fetch_sim_mock, ufs = ufs)
sim <- sim_raw %>%
  filter(starts_with_any(CAUSABAS, c("F32","F33"))) %>%
  derive_ano() %>%
  group_by(UF, .ano) %>%
  summarise(
    obitos = sum(OBITOS, na.rm = TRUE),
    .groups = "drop"
  )

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
