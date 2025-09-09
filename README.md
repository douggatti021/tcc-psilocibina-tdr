# TCC Psilocibina e TDR — Processamento de Dados DATASUS (F32/F33)

Este repositório contém o fluxo de trabalho e scripts para análise dos microdados do DATASUS relacionados a episódios depressivos (CID-10 F32) e transtorno depressivo recorrente (CID-10 F33), utilizados no Trabalho de Conclusão de Curso.

---

## 1. Ambiente computacional
- **Linguagem**: R (≥ 4.3.x)  
- **Interface**: RStudio (Posit Software)  
- **Sistemas operacionais**: Windows / macOS / Linux  
- **Registro de sessão**: ao final dos scripts, executar `sessionInfo()`  

**Pacotes principais**:  
- microdatasus (via GitHub)  
- remotes (instalação remota de pacotes)  
- dplyr, stringr, lubridate, readr, tidyr, purrr (manipulação de dados — tidyverse)  
- openxlsx (exportação para Excel)  

---

## 2. Fontes de dados
- DATASUS/SIM-DO (Declaração de Óbito)  
- DATASUS/SIH-RD (Internações hospitalares)  
- DATASUS/SIA-PA (Atendimentos ambulatoriais)  
- CID-10 (capítulos F32–F33)  
- IBGE (códigos de municípios/UF)  

Microdados em formato `.dbc` obtidos via portal do DATASUS.

---

## 3. Escopo do estudo
- **Período**: 2015–2024  
- **Cobertura geográfica**: Brasil inteiro (padrão), com possibilidade de restringir por UF.  
- **Diagnósticos**: F32 e F33 (CID-10).  

---

## 4. Estrutura do processamento
### 4.1 Instalação e configuração
- Instalação dos pacotes necessários  
- Criação dos diretórios `saida_dados/` e `cache_rds/`  

### 4.2 Funções auxiliares
- `muni_to_uf_sigla()` → converte código IBGE em sigla da UF  
- `starts_with_any()` → filtra diagnósticos por prefixo (F32/F33)  
- `derive_ano()` → extrai ano de variáveis (ANO_CMPT, DTOBITO etc.)  
- `fetch_by_years()` → baixa dados ano a ano  

### 4.3 Fluxo por sistema
- **SIH-RD (internações)** → óbitos, dias de internação, gasto total por UF × ano  
- **SIA-PA (ambulatorial)** → número de atendimentos por UF × ano  
- **SIM-DO (óbitos)** → óbitos por UF × ano  

---

## 5. Saídas produzidas
- Arquivos `.csv` (um por sistema, se flags `write_csv_* = TRUE`)  
- Planilha Excel consolidada: `datasus_f32_f33_uf_ano.xlsx`  
  - `SIH_internacoes`  
  - `SIA_atendimentos`  
  - `SIM_obitos`  

---

## 6. Integração com GraphPad Prism
Os dados exportados do R já são tabulados e anonimizados, prontos para:  
- Construção de gráficos (barras, séries temporais)  
- Testes estatísticos (paramétricos ou não-paramétricos, conforme distribuição)  

---

## 7. Boas práticas e limitações
**Boas práticas**  
- Uso de cache `.rds` para evitar downloads repetidos  
- Registro de `sessionInfo()`  
- Código aberto e pacotes estáveis  

**Limitações**  
- Subnotificação e erros de digitação/codificação no DATASUS  
- Diagnóstico limitado ao principal (internações/atendimentos) ou causa básica (óbitos)  
- Perda de granularidade mensal devido à agregação anual  
- Dependência de disponibilidade dos servidores do DATASUS  

---

## 8. Como executar

### 8.1 Pré-requisitos
- **R ≥ 4.3** (RStudio opcional)
- **Git** instalado
- **macOS**: se for usar gráficos fora do RStudio, instale **XQuartz**

---

### 8.2 Clonar o repositório
git clone https://github.com/douggatti021/tcc-psilocibina-tdr
cd tcc-psilocibina-tdr

---

### 8.3 Preparar ambiente
make setup   # ou: Rscript scripts/setup.R

---

### 8.4 Rodar pipeline
make run     # ou: Rscript scripts/pipeline.R

---

### Saídas
- CSVs: `saida_dados/`
- Excel: `resultados/datasus_f32_f33_uf_ano.xlsx`

## Referências

- BRASIL. Ministério da Saúde. [DATASUS – Departamento de Informática do SUS](https://datasus.saude.gov.br/). Acesso em: 8 set. 2025.  
- BRASIL. Ministério da Saúde. [Produção Hospitalar (SIH/SUS)](https://datasus.saude.gov.br/transferencia-de-arquivos/). Acesso em: 8 set. 2025.  
- BRASIL. Ministério da Saúde. [Produção Ambulatorial (SIA/SUS)](https://datasus.saude.gov.br/transferencia-de-arquivos/). Acesso em: 8 set. 2025.  
- SALDANHA, R. F.; BASTOS, R. R.; BARCELLOS, C. *Microdatasus: pacote para download e pré-processamento de microdados do DATASUS*. Cadernos de Saúde Pública, 2019. [https://doi.org/10.1590/0102-311X00181918](https://doi.org/10.1590/0102-311X00181918)  
- WHO. *ICD-10: International Statistical Classification of Diseases and Related Health Problems*. Geneva: World Health Organization, 2019.  
- IBGE. [Códigos de Municípios](https://www.ibge.gov.br/).  
- R CORE TEAM. *R: A Language and Environment for Statistical Computing*. Vienna: R Foundation for Statistical Computing, 2023.  
- RSTUDIO TEAM. *RStudio: Integrated Development for R*. Boston: Posit Software, 2023.  
- GRAPHPAD SOFTWARE. *GraphPad Prism (versão X.Y)*. San Diego: GraphPad Software, 2025. [https://www.graphpad.com/](https://www.graphpad.com/)  
