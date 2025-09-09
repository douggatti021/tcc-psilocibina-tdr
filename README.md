
# TCC — Psilocibina no TDR

Repositório do projeto em R (RStudio) com fluxo de extração/transformação e análise.

## Estrutura
- `scripts/`: códigos R
- `dados/`: insumos brutos (não versionar dados sensíveis/grandes)
- `saida_dados/`: saídas intermediárias (CSV)
- `resultados/`: tabelas e gráficos finais
- `docs/`: documentação e anotações

## Como rodar
1. Instale pacotes (ver `scripts/00_setup_pacotes.R`).
2. Execute o pipeline em `scripts/pipeline.R`.
3. Saídas aparecerão em `saida_dados/` e `resultados/`.

