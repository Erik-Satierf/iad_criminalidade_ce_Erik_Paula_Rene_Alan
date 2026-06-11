-- ============================================================
-- ARQUIVO: 01_criacao.sql
-- PROJETO: Análise de Criminalidade no Ceará (2009–2025)
-- FONTE:   SSPDS-CE — sspds.ce.gov.br
-- DESCRIÇÃO: Criação do schema e de todas as tabelas do banco
-- ============================================================

-- Criamos um schema próprio para isolar o projeto
-- Schema é como uma "pasta" dentro do banco PostgreSQL
CREATE SCHEMA IF NOT EXISTS criminalidade;

-- Define o schema padrão da sessão para não precisar prefixar tudo
SET search_path TO criminalidade;
-- ------------------------------------------------------------
-- dim_municipio
-- Guarda os 184 municípios do Ceará presentes nos dados.
-- Separamos em tabela própria para evitar repetir o nome
-- do município em dezenas de milhares de linhas.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS criminalidade.dim_municipio (
    id_municipio  SERIAL       PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL UNIQUE
);


-- ------------------------------------------------------------
-- dim_ais
-- AIS = Área Integrada de Segurança Pública.
-- São regiões geográficas de segurança definidas pela SSPDS.
-- O Ceará tem 34 AIS numeradas + 2 casos "Não Identificada".
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS criminalidade.dim_ais (
    id_ais  SERIAL      PRIMARY KEY,
    codigo  VARCHAR(50) NOT NULL UNIQUE
);


-- ------------------------------------------------------------
-- dim_natureza
-- Tipo jurídico do crime (apenas para ocorrências CVLI).
-- Valores: HOMICIDIO DOLOSO, FEMINICÍDIO, LATROCÍNIO, etc.
-- Intervenção Policial e Unidade Prisional não possuem esse campo.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS criminalidade.dim_natureza (
    id_natureza SERIAL       PRIMARY KEY,
    descricao   VARCHAR(100) NOT NULL UNIQUE
);


-- ------------------------------------------------------------
-- dim_meio_empregado
-- Instrumento ou método usado para cometer o crime.
-- Valores: Arma de fogo, Arma branca, Outros meios, Não informado.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS criminalidade.dim_meio_empregado (
    id_meio   SERIAL      PRIMARY KEY,
    descricao VARCHAR(50) NOT NULL UNIQUE
);


-- ------------------------------------------------------------
-- dim_escolaridade
-- Nível de escolaridade da vítima.
-- A coluna ordem_nivel é FUNDAMENTAL: permite ordenar corretamente
-- os níveis educacionais em relatórios e gráficos.
-- Sem ela, ORDER BY descricao ordena alfabeticamente,
-- colocando "Não Alfabetizado" no meio da lista (letra N).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS criminalidade.dim_escolaridade (
    id_escolaridade SERIAL      PRIMARY KEY,
    descricao       VARCHAR(60) NOT NULL UNIQUE,
    ordem_nivel     SMALLINT    NOT NULL  -- 0=Não Informada, 1=Não Alfabetizado, ..., 8=Superior Completo
);


-- ============================================================
-- TABELA FATO
-- Centraliza todos os eventos de morte violenta.
-- Cada linha representa UMA VÍTIMA de UMA ocorrência.
-- Unifica as 3 abas do Excel: CVLI, Intervenção Policial
-- e Unidade Prisional — identificadas pela coluna tipo_ocorrencia.
-- ============================================================

CREATE TABLE IF NOT EXISTS criminalidade.fato_ocorrencia (
    id_ocorrencia   SERIAL  PRIMARY KEY,

    -- Tipo de ocorrência — diferencia a origem da aba do Excel
    -- Valores possíveis: 'CVLI', 'INTERVENCAO_POLICIAL', 'UNIDADE_PRISIONAL'
    tipo_ocorrencia VARCHAR(30) NOT NULL,

    -- Chaves estrangeiras para as dimensões
    -- Município é NULL para Unidade Prisional (dado ausente na fonte)
    id_municipio    INT REFERENCES criminalidade.dim_municipio(id_municipio),
    id_ais          INT REFERENCES criminalidade.dim_ais(id_ais),

    -- Natureza é NULL para Intervenção Policial e Unidade Prisional
    id_natureza     INT REFERENCES criminalidade.dim_natureza(id_natureza),
    id_meio         INT REFERENCES criminalidade.dim_meio_empregado(id_meio),
    id_escolaridade INT REFERENCES criminalidade.dim_escolaridade(id_escolaridade),

    -- Data e hora do crime
    data_ocorrencia DATE NOT NULL,
    hora_ocorrencia TIME,

    -- Dia da semana mantido como texto: são 7 valores fixos,
    -- criar uma tabela de dimensão pra isso seria over-engineering
    dia_semana      VARCHAR(10),

    -- Dados da vítima
    genero_vitima   VARCHAR(20),

    -- Idade como INTEGER com NULL quando não informada.
    -- Manter como texto ('Não Informada') impossibilitaria
    -- cálculos como AVG(), MIN(), MAX() e filtros como WHERE idade < 18.
    idade_vitima    SMALLINT,   -- NULL = não informada

    raca_vitima     VARCHAR(20),

    -- Colunas derivadas para facilitar análises sem JOIN
    -- Desnormalização controlada e justificada: ano e mês são
    -- consultados em praticamente toda análise temporal
    ano             SMALLINT    NOT NULL GENERATED ALWAYS AS (EXTRACT(YEAR  FROM data_ocorrencia)::SMALLINT) STORED,
    mes             SMALLINT    NOT NULL GENERATED ALWAYS AS (EXTRACT(MONTH FROM data_ocorrencia)::SMALLINT) STORED
);


-- ============================================================
-- ÍNDICES
-- Índices aceleram consultas em colunas muito filtradas.
-- Sem índice, o banco lê todas as 61k linhas a cada query.
-- Com índice, ele vai direto ao dado — como um índice de livro.
-- ============================================================

-- Filtros temporais são os mais comuns em análise de crime
CREATE INDEX IF NOT EXISTS idx_fato_ano       ON criminalidade.fato_ocorrencia(ano);
CREATE INDEX IF NOT EXISTS idx_fato_data      ON criminalidade.fato_ocorrencia(data_ocorrencia);

-- Filtros geográficos também muito usados
CREATE INDEX IF NOT EXISTS idx_fato_municipio ON criminalidade.fato_ocorrencia(id_municipio);
CREATE INDEX IF NOT EXISTS idx_fato_ais       ON criminalidade.fato_ocorrencia(id_ais);

-- Filtro por tipo de ocorrência para separar CVLI de intervenção
CREATE INDEX IF NOT EXISTS idx_fato_tipo      ON criminalidade.fato_ocorrencia(tipo_ocorrencia);