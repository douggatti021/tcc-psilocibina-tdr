
# Pipeline principal: extração -> transformação -> saídas
source("scripts/helpers.R")
message("Iniciando pipeline...")

# Exemplo de checagem de pastas de saída
dir.create("saida_dados", showWarnings = FALSE)
dir.create("resultados", showWarnings = FALSE)

# TODO: inserir etapas de microdatasus (fetch_sih/sia/sim), joins, sumarizações
# TODO: gerar CSVs em saida_dados/ e planilha final em resultados/

message("Pipeline finalizado (esqueleto).")

