-- ============================================================
-- ARQUIVO: 04_consultas.sql
-- DESCRIÇÃO: Consultas analíticas e views para dashboard
-- PRÉ-REQUISITO: 03_tratamento.sql executado com sucesso
-- EXECUÇÃO: Alt+X no DBeaver
-- ============================================================

SET search_path TO criminalidade;

-- ============================================================
-- PERGUNTA 1
-- Como evoluiu o número de mortes violentas no Ceará
-- entre 2009 e 2025?
-- ============================================================

SELECT
    ano,
    COUNT(*)                                                      AS total_mortes,
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY ano)                  AS variacao_absoluta,
    ROUND(
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY ano))
        * 100.0
        / NULLIF(LAG(COUNT(*)) OVER (ORDER BY ano), 0)
    , 1)                                                          AS variacao_percentual
FROM criminalidade.fato_ocorrencia
GROUP BY ano
ORDER BY ano;

-- ============================================================
-- PERGUNTA 2
-- Quais os 10 municípios com mais mortes violentas (CVLI)?
-- ============================================================

SELECT
    m.nome                                                        AS municipio,
    COUNT(*)                                                      AS total_mortes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)           AS perc_do_total
FROM criminalidade.fato_ocorrencia f
JOIN criminalidade.dim_municipio m ON m.id_municipio = f.id_municipio
WHERE f.tipo_ocorrencia = 'CVLI'
GROUP BY m.nome
ORDER BY total_mortes DESC
LIMIT 10;

-- ============================================================
-- PERGUNTA 3
-- Qual o perfil da vítima de homicídio no Ceará?
-- ============================================================

-- 3A: Por gênero
SELECT
    genero_vitima,
    COUNT(*)                                                      AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)           AS percentual
FROM criminalidade.fato_ocorrencia
WHERE tipo_ocorrencia = 'CVLI'
GROUP BY genero_vitima
ORDER BY total DESC;

-- 3B: Por raça
SELECT
    raca_vitima,
    COUNT(*)                                                      AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)           AS percentual
FROM criminalidade.fato_ocorrencia
WHERE tipo_ocorrencia = 'CVLI'
GROUP BY raca_vitima
ORDER BY total DESC;

-- 3C: Por faixa etária
SELECT
    CASE
        WHEN idade_vitima IS NULL               THEN '00. Não Informada'
        WHEN idade_vitima < 12                  THEN '01. Criança (< 12)'
        WHEN idade_vitima BETWEEN 12 AND 17     THEN '02. Adolescente (12–17)'
        WHEN idade_vitima BETWEEN 18 AND 24     THEN '03. Jovem (18–24)'
        WHEN idade_vitima BETWEEN 25 AND 34     THEN '04. Adulto jovem (25–34)'
        WHEN idade_vitima BETWEEN 35 AND 49     THEN '05. Adulto (35–49)'
        WHEN idade_vitima BETWEEN 50 AND 64     THEN '06. Meia-idade (50–64)'
        ELSE                                         '07. Idoso (65+)'
    END                                                           AS faixa_etaria,
    COUNT(*)                                                      AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)           AS percentual
FROM criminalidade.fato_ocorrencia
WHERE tipo_ocorrencia = 'CVLI'
GROUP BY faixa_etaria
ORDER BY faixa_etaria;

-- ============================================================
-- PERGUNTA 4
-- Há padrão temporal nos homicídios?
-- ============================================================

-- 4A: Por dia da semana
SELECT
    dia_semana,
    COUNT(*)                                                      AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)           AS percentual
FROM criminalidade.fato_ocorrencia
WHERE tipo_ocorrencia = 'CVLI'
  AND dia_semana IS NOT NULL
GROUP BY dia_semana
ORDER BY CASE dia_semana
    WHEN 'Segunda' THEN 1 WHEN 'Terça'   THEN 2
    WHEN 'Quarta'  THEN 3 WHEN 'Quinta'  THEN 4
    WHEN 'Sexta'   THEN 5 WHEN 'Sábado'  THEN 6
    WHEN 'Domingo' THEN 7 END;

-- 4B: Por turno
SELECT
    CASE
        WHEN hora_ocorrencia BETWEEN '06:00' AND '11:59' THEN '1. Manhã (06h–12h)'
        WHEN hora_ocorrencia BETWEEN '12:00' AND '17:59' THEN '2. Tarde (12h–18h)'
        WHEN hora_ocorrencia BETWEEN '18:00' AND '23:59' THEN '3. Noite (18h–00h)'
        WHEN hora_ocorrencia <  '06:00'                  THEN '4. Madrugada (00h–06h)'
        ELSE                                                  '5. Hora não informada'
    END                                                           AS turno,
    COUNT(*)                                                      AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)           AS percentual
FROM criminalidade.fato_ocorrencia
WHERE tipo_ocorrencia = 'CVLI'
GROUP BY turno
ORDER BY turno;

-- ============================================================
-- PERGUNTA 5
-- Qual meio foi mais usado e como variou ao longo do tempo?
-- ============================================================

SELECT
    ano,
    me.descricao                                                  AS meio_empregado,
    COUNT(*)                                                      AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY ano), 1) AS perc_no_ano
FROM criminalidade.fato_ocorrencia f
JOIN criminalidade.dim_meio_empregado me ON me.id_meio = f.id_meio
WHERE f.tipo_ocorrencia = 'CVLI'
GROUP BY ano, me.descricao
ORDER BY ano, total DESC;

-- ============================================================
-- PERGUNTA 6
-- Como difere o perfil de vítima entre os 3 tipos de morte?
-- ============================================================

SELECT
    tipo_ocorrencia,
    COUNT(*)                                                      AS total_vitimas,
    ROUND(AVG(idade_vitima), 1)                                   AS media_idade,
    ROUND(
        SUM(CASE WHEN genero_vitima = 'Masculino' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1
    )                                                             AS perc_masculino,
    ROUND(
        SUM(CASE WHEN raca_vitima IN ('Parda', 'Preta') THEN 1 ELSE 0 END)
        * 100.0 / NULLIF(
            SUM(CASE WHEN raca_vitima != 'Não Informada' THEN 1 ELSE 0 END), 0
        ), 1
    )                                                             AS perc_negros_informados
FROM criminalidade.fato_ocorrencia
GROUP BY tipo_ocorrencia
ORDER BY total_vitimas DESC;

-- ============================================================
-- VIEWS PARA DASHBOARD
-- O Power BI e Looker Studio enxergam views como tabelas.
-- ============================================================

-- Série temporal — gráfico de linha
CREATE OR REPLACE VIEW criminalidade.vw_serie_anual AS
SELECT
    ano,
    tipo_ocorrencia,
    COUNT(*) AS total
FROM criminalidade.fato_ocorrencia
GROUP BY ano, tipo_ocorrencia
ORDER BY ano;

-- Ranking de municípios — mapa ou barras
CREATE OR REPLACE VIEW criminalidade.vw_ranking_municipios AS
SELECT
    m.nome   AS municipio,
    f.ano,
    COUNT(*) AS total_cvli
FROM criminalidade.fato_ocorrencia f
JOIN criminalidade.dim_municipio m ON m.id_municipio = f.id_municipio
WHERE f.tipo_ocorrencia = 'CVLI'
GROUP BY m.nome, f.ano
ORDER BY f.ano, total_cvli DESC;

-- Perfil da vítima — pizza ou barras
CREATE OR REPLACE VIEW criminalidade.vw_perfil_vitima AS
SELECT
    tipo_ocorrencia,
    genero_vitima,
    raca_vitima,
    e.descricao  AS escolaridade,
    e.ordem_nivel,
    COUNT(*)     AS total
FROM criminalidade.fato_ocorrencia f
LEFT JOIN criminalidade.dim_escolaridade e ON e.id_escolaridade = f.id_escolaridade
GROUP BY tipo_ocorrencia, genero_vitima, raca_vitima, e.descricao, e.ordem_nivel
ORDER BY tipo_ocorrencia, total DESC;

-- Padrão temporal — heatmap dia x turno
CREATE OR REPLACE VIEW criminalidade.vw_padrao_temporal AS
SELECT
    dia_semana,
    CASE
        WHEN hora_ocorrencia BETWEEN '06:00' AND '11:59' THEN 'Manhã'
        WHEN hora_ocorrencia BETWEEN '12:00' AND '17:59' THEN 'Tarde'
        WHEN hora_ocorrencia BETWEEN '18:00' AND '23:59' THEN 'Noite'
        WHEN hora_ocorrencia <  '06:00'                  THEN 'Madrugada'
        ELSE 'Não informado'
    END          AS turno,
    COUNT(*)     AS total
FROM criminalidade.fato_ocorrencia
WHERE tipo_ocorrencia = 'CVLI'
  AND dia_semana IS NOT NULL
GROUP BY dia_semana, turno;