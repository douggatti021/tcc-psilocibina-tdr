# scripts/pipeline.R
# ============================================================
# Pipeline principal: extração -> transformação -> saídas
# Sistemas suportados: "SIH-RD", "SIA-PA", "SIM-DO"
# Saídas: CSVs em ./saida_dados e Excel em ./resultados
# ============================================================

options(encoding = "UTF-8", timeout = 1800)
message("Iniciando pipeline...")

# --- Dependências mínimas ---
suppressPackageStartupMessages({
  req <- c("utils","tools","fs","dplyr","readr","purrr","tibble",
           "tidyr","lubridate","openxlsx")
  to_install <- setdiff(req, rownames(installed.packages()))
  if (length(to_install)) install.packages(to_install, quiet = TRUE)
  lapply(req, require, character.only = TRUE)
})

# microdatasus: CRAN ou GitHub (fallback)
if (!requireNamespace("microdatasus", quietly = TRUE)) {
  message("Instalando microdatasus...")
  try(install.packages("microdatasus", quiet = TRUE), silent = TRUE)
}
if (!requireNamespace("microdatasus", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes", quiet = TRUE)
  remotes::install_github("rfsaldanha/microdatasus", upgrade = "never", quiet = TRUE)
}
library(microdatasus)

# Helpers opcionais (não obrigatório)
if (file.exists("scripts/helpers.R")) source("scripts/helpers.R")

# --- Parâmetros de TESTE ---
SISTEMAS  <- c("SIH-RD", "SIA-PA", "SIM-DO")  
UFS       <- c("PR")      # Paraná
ANOS      <- 2019:2021    # agora os três anos
MAX_TENT  <- 3
AMOSTRA   <- 2000         # pequena amostra p/ validar fluxo multi-sistema

# --- Pastas de saída ---
dir.create("saida_dados", showWarnings = FALSE)
dir.create("resultados",  showWarnings = FALSE)

# --- Registro de falhas ---
failed_downloads <- list()

# --- Retry com backoff exponencial e meses explícitos ---
fetch_sistema <- function(sistema, uf, ano, max_tentativas = MAX_TENT, ...) {
  sistema <- as.character(sistema)
  uf      <- toupper(as.character(uf))
  ano     <- as.integer(ano)
  
  last_error <- NULL
  for (tentativa in seq_len(max_tentativas)) {
    resultado <- try({
      microdatasus::fetch_datasus(
        year_start = ano, month_start = 1,
        year_end   = ano, month_end   = 12,
        uf = uf, information_system = sistema,
        ...
      )
    }, silent = TRUE)
    
    if (!inherits(resultado, "try-error")) return(resultado)
    
    cond <- attr(resultado, "condition")
    last_error <- tryCatch(conditionMessage(cond), error = function(e) as.character(resultado))
    message(sprintf("Tentativa %d falhou (%s/%s/%s): %s",
                    tentativa, sistema, uf, ano, last_error))
    Sys.sleep(2^(tentativa - 1))  # backoff: 1s,2s,4s...
  }
  
  message(sprintf("Falha no download: sistema=%s UF=%s ano=%s. Último erro: %s",
                  sistema, uf, ano, last_error))
  failed_downloads[[length(failed_downloads) + 1]] <<- list(
    sistema = sistema, uf = uf, ano = ano, erro = last_error
  )
  return(tibble::tibble())
}

# --- Processador por sistema ---
processar_sistema <- function(sistema, df) {
  if (nrow(df) == 0) return(df)
  
  out <- switch(
    sistema,
    "SIH-RD" = microdatasus::process_sih(df),
    "SIA-PA" = microdatasus::process_sia(df),
    "SIM-DO" = microdatasus::process_sim(df),
    {
      warning(sprintf("Sistema %s sem processador dedicado; retornando bruto.", sistema))
      df
    }
  )
  
  # Amostragem para teste
  if (!is.null(AMOSTRA) && nrow(out) > AMOSTRA) {
    out <- dplyr::slice_head(out, n = AMOSTRA)
  }
  
  out <- dplyr::mutate(out, SISTEMA = sistema, UF = df$UF[1])
  out
}

# --- Download + processamento ---
baixar_por_sistema <- function(sistema, ufs, anos, ...) {
  raws <- purrr::map(ufs, function(uf) {
    purrr::map(anos, function(ano) fetch_sistema(sistema, uf, ano, ..., max_tentativas = MAX_TENT))
  }) |> unlist(recursive = FALSE)
  
  raws <- Filter(function(x) !is.null(x) && is.data.frame(x) && nrow(x) > 0, raws)
  if (!length(raws)) return(tibble::tibble())
  
  procs <- purrr::map2(raws, seq_along(raws), function(df, i) {
    if (!"UF" %in% names(df)) {
      df$UF <- df$UF_RESIDENCIA %||% df$UF_ZI %||% NA_character_
    }
    processar_sistema(sistema, df)
  })
  
  dplyr::bind_rows(procs)
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

# --- Execução principal ---
todos_consolidados <- list()

for (sis in SISTEMAS) {
  message(sprintf(">>> Iniciando %s", sis))
  
  # 1) baixar + processar
  dados_proc <- baixar_por_sistema(sis, UFS, ANOS)
  if (nrow(dados_proc) == 0) {
    message(sprintf("Sem dados processados para %s.", sis))
    next
  }
  
  # 2) ANO a partir da data correta do sistema
  col_data <- intersect(c("DT_INTER","DT_ATEND","DTOBITO"), names(dados_proc))
  if (length(col_data)) {
    base_date <- col_data[1]
    dados_proc$ANO <- as.integer(format(as.Date(dados_proc[[base_date]]), "%Y"))
  } else {
    dados_proc$ANO <- NA_integer_
  }
  
  # 3) UF: código IBGE -> sigla (robusto a numérico ou string "410000")
  uf_map <- c(
    "11"="RO","12"="AC","13"="AM","14"="RR","15"="PA","16"="AP","17"="TO",
    "21"="MA","22"="PI","23"="CE","24"="RN","25"="PB","26"="PE","27"="AL","28"="SE","29"="BA",
    "31"="MG","32"="ES","33"="RJ","35"="SP",
    "41"="PR","42"="SC","43"="RS",
    "50"="MS","51"="MT","52"="GO","53"="DF"
  )
  
  if ("UF" %in% names(dados_proc)) {
    UF_chr <- as.character(dados_proc$UF)
    
    # Se for "410000" (texto ou número convertido), pega os dois primeiros dígitos
    # Se já for "PR"/"SP"... mantém
    uf_code2 <- suppressWarnings(as.integer(substr(UF_chr, 1, 2)))
    sigla_calc <- uf_map[as.character(uf_code2)]
    
    # Onde conseguirmos mapear, usamos a sigla; senão preservamos o valor original
    dados_proc$UF_SIGLA <- ifelse(!is.na(sigla_calc), sigla_calc, UF_chr)
  } else if (!"UF_SIGLA" %in% names(dados_proc)) {
    dados_proc$UF_SIGLA <- NA_character_
  }
  
  # 4) Filtro estrito pelos anos solicitados
  if (exists("ANOS") && is.numeric(ANOS)) {
    dados_proc <- subset(dados_proc, ANO %in% ANOS)
  }
  
  # 5) Salvar CSV deste sistema
  csv_path <- file.path("saida_dados",
                        sprintf("consolidado_%s_%s.csv", gsub("-", "", sis), format(Sys.Date())))
  readr::write_csv(dados_proc, csv_path, na = "")
  message("Salvo: ", csv_path, " (", nrow(dados_proc), " linhas)")
  
  # 6) Acumular para Excel consolidado
  todos_consolidados[[sis]] <- dados_proc
}

# --- Excel consolidado com resumo (por UF_SIGLA) ---
if (length(todos_consolidados)) {
  wb <- openxlsx::createWorkbook()
  
  # Abas por sistema
  for (nm in names(todos_consolidados)) {
    openxlsx::addWorksheet(wb, nm)
    openxlsx::writeData(wb, nm, todos_consolidados[[nm]])
  }
  
  # Conjunto geral
  geral <- dplyr::bind_rows(todos_consolidados)
  if (!"UF_SIGLA" %in% names(geral) && "UF" %in% names(geral)) {
    geral$UF_SIGLA <- as.character(geral$UF)
  }
  
  # Aba 'resumo' (SISTEMA × UF_SIGLA × ANO)
  resumo <- geral |>
    dplyr::mutate(ANO = as.integer(ANO)) |>
    dplyr::count(SISTEMA, UF_SIGLA, ANO, name = "n_registros") |>
    dplyr::arrange(SISTEMA, UF_SIGLA, ANO)
  
  openxlsx::addWorksheet(wb, "resumo")
  openxlsx::writeData(wb, "resumo", resumo)
  
  # Aba opcional de depressão (F32/F33) no SIH
  if ("DIAG_PRINC" %in% names(geral)) {
    geral_dep <- dplyr::filter(
      geral,
      !is.na(DIAG_PRINC) & grepl("^(F32|F33)", toupper(DIAG_PRINC))
    )
    openxlsx::addWorksheet(wb, "SIH_F32F33")
    openxlsx::writeData(wb, "SIH_F32F33", geral_dep)
    message("Aba 'SIH_F32F33' adicionada ao Excel (", nrow(geral_dep), " linhas).")
  }
  
  # Salvar Excel
  xlsx_path <- file.path("resultados",
                         sprintf("consolidado_datasus_%s.xlsx", format(Sys.Date())))
  openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)
  message("Excel gerado: ", xlsx_path)
} else {
  message("Nenhum dado consolidado para gerar Excel.")
}
  
# --- Falhas reportadas ---
if (length(failed_downloads) > 0) {
  message("Combinações de UF/ano com falha de download:")
  falhas_df <- do.call(rbind, lapply(failed_downloads, as.data.frame))
  print(falhas_df)
}

message("Pipeline finalizado.")
