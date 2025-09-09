# scripts/setup.R
# Configura diretórios e opções básicas de reprodutibilidade

options(repos = c(CRAN = "https://cran.r-project.org"))
options(stringsAsFactors = FALSE)

dirs <- c("dados", "resultados", "cache_rds", "saida_dados")
sapply(dirs, dir.create, showWarnings = FALSE, recursive = TRUE)

message("Setup concluído. Diretórios prontos: ", paste(dirs, collapse = ", "))
