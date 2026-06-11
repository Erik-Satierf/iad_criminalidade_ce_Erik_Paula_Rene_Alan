-- ============================================================
-- ARQUIVO: 03_tratamento.sql
-- DESCRIÇÃO: Limpeza e carga na tabela fato
-- PRÉ-REQUISITO: 02_importacao.sql executado e CSVs importados
-- EXECUÇÃO: Execute cada bloco separadamente com Ctrl+Enter
-- ============================================================

SET search_path TO criminalidade;

-- ============================================================
-- PASSO 1 — VERIFICAR STAGINGS
-- Execute antes de qualquer INSERT para confirmar os totais.
-- ============================================================

SELECT 'staging_cvli'        AS tabela, COUNT(*) AS total FROM criminalidade.staging_cvli
UNION ALL
SELECT 'staging_intervencao', COUNT(*) FROM criminalidade.staging_intervencao
UNION ALL
SELECT 'staging_prisional',   COUNT(*) FROM criminalidade.staging_prisional;
-- Esperado: 59340 / 1765 / 231

-- ============================================================
-- PASSO 2 — DIAGNÓSTICO DE QUALIDADE
-- Identifica valores que não existem nas dimensões.
-- Se retornar linhas, há dados sujos que virarão NULL na fato.
-- ============================================================

-- AIS sem correspondência na dimensão
SELECT DISTINCT s.ais
FROM criminalidade.staging_cvli s
WHERE NOT EXISTS (
    SELECT 1 FROM criminalidade.dim_ais d WHERE d.codigo = TRIM(s.ais)
);

-- Municípios sem correspondência na dimensão
SELECT DISTINCT s.municipio
FROM criminalidade.staging_cvli s
WHERE NOT EXISTS (
    SELECT 1 FROM criminalidade.dim_municipio d WHERE d.nome = TRIM(s.municipio)
);

-- ============================================================
-- PASSO 3 — INSERIR NA TABELA FATO
--
-- Decisões de tratamento aplicadas:
-- • TRIM() remove espaços invisíveis vindos do Excel
-- • to_date(..., 'DD/MM/YYYY') converte texto para DATE
--   (Excel brasileiro exporta nesse formato, não YYYY-MM-DD)
-- • idade TEXT → SMALLINT: 'Não Informada' vira NULL
--   para permitir AVG(), MIN(), MAX() na análise
-- • Colunas ausentes na fonte ficam NULL (ex: municipio
--   não existe na aba Unidade Prisional)
-- ============================================================

-- --- ABA CVLI (59.340 registros) ---
INSERT INTO criminalidade.fato_ocorrencia (
    tipo_ocorrencia, id_municipio, id_ais, id_natureza, id_meio,
    id_escolaridade, data_ocorrencia, hora_ocorrencia, dia_semana,
    genero_vitima, idade_vitima, raca_vitima
)
SELECT
    'CVLI',
    (SELECT id_municipio FROM criminalidade.dim_municipio WHERE nome = TRIM(s.municipio)),
    (SELECT id_ais FROM criminalidade.dim_ais WHERE codigo = TRIM(s.ais)),
    (SELECT id_natureza FROM criminalidade.dim_natureza WHERE descricao = TRIM(s.natureza)),
    (SELECT id_meio FROM criminalidade.dim_meio_empregado WHERE descricao = TRIM(s.meio_empregado)),
    (SELECT id_escolaridade FROM criminalidade.dim_escolaridade WHERE descricao = TRIM(s.escolaridade)),
    to_date(s.data, 'DD/MM/YYYY'),
    NULLIF(TRIM(s.hora), '')::TIME,
    TRIM(s.dia_semana),
    TRIM(s.genero),
    CASE
        WHEN TRIM(s.idade_vitima) = 'Não Informada' THEN NULL
        WHEN TRIM(s.idade_vitima) ~ '^\d+$' THEN TRIM(s.idade_vitima)::SMALLINT
        ELSE NULL
    END,
    TRIM(s.raca)
FROM criminalidade.staging_cvli s
WHERE s.data IS NOT NULL;

-- --- ABA INTERVENÇÃO POLICIAL (1.765 registros) ---
-- Natureza não existe nessa aba → id_natureza = NULL
INSERT INTO criminalidade.fato_ocorrencia (
    tipo_ocorrencia, id_municipio, id_ais, id_natureza, id_meio,
    id_escolaridade, data_ocorrencia, hora_ocorrencia, dia_semana,
    genero_vitima, idade_vitima, raca_vitima
)
SELECT
    'INTERVENCAO_POLICIAL',
    (SELECT id_municipio FROM criminalidade.dim_municipio WHERE nome = TRIM(s.municipio)),
    (SELECT id_ais FROM criminalidade.dim_ais WHERE codigo = TRIM(s.ais)),
    NULL,
    (SELECT id_meio FROM criminalidade.dim_meio_empregado WHERE descricao = TRIM(s.meio_empregado)),
    (SELECT id_escolaridade FROM criminalidade.dim_escolaridade WHERE descricao = TRIM(s.escolaridade)),
    to_date(s.data, 'DD/MM/YYYY'),
    NULLIF(TRIM(s.hora), '')::TIME,
    TRIM(s.dia_semana),
    TRIM(s.genero),
    CASE
        WHEN TRIM(s.idade) = 'Não Informada' THEN NULL
        WHEN TRIM(s.idade) ~ '^\d+$' THEN TRIM(s.idade)::SMALLINT
        ELSE NULL
    END,
    TRIM(s.raca)
FROM criminalidade.staging_intervencao s
WHERE s.data IS NOT NULL;

-- --- ABA UNIDADE PRISIONAL (231 registros) ---
-- Município, natureza e meio não existem → todos NULL
INSERT INTO criminalidade.fato_ocorrencia (
    tipo_ocorrencia, id_municipio, id_ais, id_natureza, id_meio,
    id_escolaridade, data_ocorrencia, hora_ocorrencia, dia_semana,
    genero_vitima, idade_vitima, raca_vitima
)
SELECT
    'UNIDADE_PRISIONAL',
    NULL,
    (SELECT id_ais FROM criminalidade.dim_ais WHERE codigo = TRIM(s.ais)),
    NULL,
    NULL,
    (SELECT id_escolaridade FROM criminalidade.dim_escolaridade WHERE descricao = TRIM(s.escolaridade)),
    to_date(s.data, 'DD/MM/YYYY'),
    NULLIF(TRIM(s.hora), '')::TIME,
    TRIM(s.dia_semana),
    TRIM(s.genero),
    CASE
        WHEN TRIM(s.idade) = 'Não Informada' THEN NULL
        WHEN TRIM(s.idade) ~ '^\d+$' THEN TRIM(s.idade)::SMALLINT
        ELSE NULL
    END,
    TRIM(s.raca)
FROM criminalidade.staging_prisional s
WHERE s.data IS NOT NULL;

-- ============================================================
-- PASSO 4 — VALIDAÇÃO FINAL
-- ============================================================

-- Totais por tipo — esperado: 59340 / 1765 / 231
SELECT tipo_ocorrencia, COUNT(*) AS total
FROM criminalidade.fato_ocorrencia
GROUP BY tipo_ocorrencia
ORDER BY total DESC;

-- Estatísticas de idade
SELECT
    COUNT(*)                        AS total_registros,
    COUNT(idade_vitima)             AS com_idade,
    COUNT(*) - COUNT(idade_vitima)  AS sem_idade_null,
    ROUND(AVG(idade_vitima), 1)     AS media_idade,
    MIN(idade_vitima)               AS idade_minima,
    MAX(idade_vitima)               AS idade_maxima
FROM criminalidade.fato_ocorrencia;

-- Distribuição por ano — deve ir de 2009 a 2025
SELECT ano, COUNT(*) AS total
FROM criminalidade.fato_ocorrencia
GROUP BY ano
ORDER BY ano;