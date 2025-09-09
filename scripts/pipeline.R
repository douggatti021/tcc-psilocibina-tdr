# scripts/pipeline.R
# Ponto de entrada do projeto: ajusta parâmetros, executa fluxo e gera saída
suppressPackageStartupMessages({
  library(tidyverse)
  library(openxlsx)
  library(rlang)        # <-- novo
})

source("scripts/setup.R")
source("scripts/helpers.R")

# ========= Parâmetros do estudo =========
anos_ini   <- 2015
anos_fim   <- 2024
ufs        <- NULL       # ex.: c("SP","RJ"); NULL = Brasil
write_csvs <- TRUE
write_xlsx <- TRUE
xlsx_path  <- file.path("resultados", "datasus_f32_f33_uf_ano.xlsx")

set.seed(123)           # <-- novo
dir.create("saida_dados", showWarnings = FALSE, recursive = TRUE)  # <-- novo
dir.create("resultados",  showWarnings = FALSE, recursive = TRUE)  # <-- novo

# ========= Funções de ingestão (mocks) =========
fetch_sih_mock <- function(ano, ufs = NULL) {
  tibble(
    UF        = ufs %||% c("SP","RJ","MG"),
    DIAS      = sample(1:15, length(ufs %||% c("SP","RJ","MG")), replace = TRUE),
    GASTO     = runif(length(ufs %||% c("SP","RJ","MG")), 1e5, 5e5),
    DIAG_PRINC= sample(c("F320","F321","F330","F331"),
                       size = length(ufs %||% c("SP","RJ","MG")), replace = TRUE),
    ANO_CMPT  = ano
  )
}
fetch_sia_mock <- function(ano, ufs = NULL) {
  tibble(
    UF        = ufs %||% c("SP","RJ","MG"),
    ATEND     = sample(50:300, length(ufs %||% c("SP","RJ","MG")), replace = TRUE),
    PA_CIDPRI = sample(c("F320","F330","F332"),
                       size = length(ufs %||% c("SP","RJ","MG")), replace = TRUE),
    PA_CMP    = paste0(ano, "01")
  )
}
fetch_sim_mock <- function(ano, ufs = NULL) {
  tibble(
    UF       = ufs %||% c("SP","RJ","MG"),
    OBITOS   = sample(5:80, length(ufs %||% c("SP","RJ","MG")), replace = TRUE),
    CAUSABAS = sample(c("F320","F330"),
                      size = length(ufs %||% c("SP","RJ","MG")), replace = TRUE),
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
  summarise(atendimentos = sum(ATEND, na.rm = TRUE), .groups = "drop")

# ========= SIM-DO =========
sim_raw <- fetch_by_years(anos, fetch_sim_mock, ufs = ufs)
sim <- sim_raw %>%
  filter(starts_with_any(CAUSABAS, c("F32","F33"))) %>%
  derive_ano() %>%
  group_by(UF, .ano) %>%
  summarise(obitos = sum(OBITOS, na.rm = TRUE), .groups = "drop")

# ========= Escrita das saídas =========
if (write_csvs) {
  readr::write_csv(sih, "saida_dados/sih_internacoes.csv")
  readr::write_csv(sia, "saida_dados/sia_atendimentos.csv")
  readr::write_csv(sim, "saida_dados/sim_obitos.csv")
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
