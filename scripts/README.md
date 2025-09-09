# Scripts

Este diretório contém os scripts principais do projeto:

- `setup.R`: cria diretórios e instala pacotes necessários.
- `config.R`: define parâmetros globais (anos, UFs, caminhos de saída).
- `helpers.R`: funções auxiliares (prefixos F32/F33, derivação de ano, etc).
- `pipeline.R`: ponto de entrada do projeto; carrega setup/config/helpers e gera as saídas (CSV e Excel).
