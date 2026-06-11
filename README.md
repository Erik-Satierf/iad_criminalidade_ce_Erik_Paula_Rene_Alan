# 🔍 Análise de Criminalidade no Ceará (2009–2025)

Trabalho final da disciplina **Introdução à Análise de Dados (IAD)** — análise de crimes violentos letais intencionais no estado do Ceará com base em dados públicos da Secretaria da Segurança Pública e Defesa Social do Ceará (SSPDS-CE).

---

## 👥 Integrantes

| Nome:
| Erik Nunes
| Ana Paula Monteiro
| José Renê
| Alan Diogenes

---

## 📋 Tema

**Opção B — Criminalidade no Ceará**

Investigação de padrões de mortes violentas no Ceará entre 2009 e 2025, com foco em:
- Evolução temporal dos homicídios
- Municípios com maior concentração de crimes
- Perfil das vítimas (gênero, raça, faixa etária)
- Padrões temporais (dia da semana e turno)
- Meios empregados nos crimes
- Comparação entre CVLI, Intervenção Policial e Unidade Prisional

---

## 🗂️ Fonte dos Dados

| Dataset | Descrição | Fonte |
|---|---|---|
| CVLI 2009–2025 | Crimes Violentos Letais Intencionais por município, vítima e período | [sspds.ce.gov.br](https://www.sspds.ce.gov.br) |

O arquivo `CVLI_2009_a_2025.xlsx` contém 3 abas:
- **CVLI** — 59.340 registros de homicídios dolosos, feminicídios e latrocínios
- **Intervenção Policial** — 1.765 registros de mortes causadas por agentes policiais
- **Unidade Prisional** — 231 registros de mortes em presídios

**Total: 61.336 vítimas**

> Os dados originais não estão no repositório por questões de tamanho. Para reproduzir a análise, baixe o arquivo diretamente em [sspds.ce.gov.br](https://www.sspds.ce.gov.br) e siga as instruções abaixo.

---

## 🗄️ Estrutura do Repositório

```
iad_criminalidade_ce_Erik_Paula_Rene_Alan/
├── README.md
├── dados/
│   └── instrucoes_download.md
├── sql/
│   ├── 01_criacao.sql      # Criação do schema e tabelas
│   ├── 02_importacao.sql   # Dimensões e staging tables
│   ├── 03_tratamento.sql   # Limpeza e carga na tabela fato
│   └── 04_consultas.sql    # Consultas analíticas e views
├── dump/
│   └── criminalidade_ce.sql  # Dump completo do banco
└── relatorio/
    └── relatorio.md          # Relatório completo do projeto
```

---

## ⚙️ Como Rodar

### Pré-requisitos
- PostgreSQL 16 ou superior
- DBeaver Community (para importação dos CSVs)

### Passo a passo

**1. Prepare os dados**
- Baixe o arquivo `CVLI_2009_a_2025.xlsx` da SSPDS-CE
- Exporte cada aba como CSV UTF-8 com separador `;`:
  - Aba CVLI → `cvli.csv`
  - Aba Intervenção Policial → `intervencao_policial.csv`
  - Aba Unidade Prisional → `unidade_prisional.csv`

**2. Crie o banco**
- Crie um banco chamado `criminalidade_ce` no PostgreSQL
- Execute `sql/01_criacao.sql` — cria schema, tabelas e índices

**3. Popule as dimensões e importe os CSVs**
- Execute `sql/02_importacao.sql` — insere dimensões e cria staging tables
- Importe os 3 CSVs nas tabelas de staging via DBeaver (Import Data)
  - Atenção: separador `;`, encoding UTF-8, mapeie as colunas manualmente

**4. Trate os dados**
- Execute `sql/03_tratamento.sql` bloco por bloco
- Valide os totais: 59.340 CVLI / 1.765 Intervenção / 231 Prisional

**5. Execute as análises**
- Execute `sql/04_consultas.sql` para ver os resultados e criar as views

### Alternativa — restaurar pelo dump

psql -U postgres -d criminalidade_ce -f dump/criminalidade_ce.sql


---

## 🏗️ Modelagem

O banco segue um modelo **Star Schema** com uma tabela fato central e 5 dimensões:

```
dim_municipio ─┐
dim_ais ───────┤
dim_natureza ──┼── fato_ocorrencia
dim_meio ──────┤
dim_escolaridade─┘
```

As 3 abas do Excel foram unificadas em uma única tabela `fato_ocorrencia` com a coluna `tipo_ocorrencia` diferenciando `CVLI`, `INTERVENCAO_POLICIAL` e `UNIDADE_PRISIONAL`.

---

## 📊 Principais Resultados

| Pergunta | Resultado |
|---|---|
| Pico de violência | 2017 com 25.864 mortes (+50% em relação a 2016) |
| Município mais violento | Fortaleza — 36% de todas as mortes do estado |
| Perfil da vítima | Homem, jovem (18–34 anos), raça parda |
| Dia mais violento | Domingo (18,8% dos casos) |
| Turno mais violento | Noite e Madrugada (63% dos casos) |
| Principal arma | Arma de fogo — presente em mais de 74% dos casos |