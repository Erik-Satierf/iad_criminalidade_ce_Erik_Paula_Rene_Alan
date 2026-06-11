# Relatório — Análise de Criminalidade no Ceará (2009–2025)

**Disciplina:** Introdução à Análise de Dados (IAD)
**Integrantes:** Erik Nunes, Ana Paula Monteiro, José Renê, Alan Diogenes
**Apresentação:** 25 de junho de 2026

---

## 1. Motivação

O Ceará figura historicamente entre os estados brasileiros com maiores índices de violência letal. Entre 2009 e 2025, o estado registrou mais de 61 mil mortes violentas — um número que equivale a eliminar completamente uma cidade do porte de Sobral.

Escolhemos esse tema por sua relevância social direta para a população cearense e pela disponibilidade de dados públicos detalhados fornecidos pela Secretaria da Segurança Pública e Defesa Social do Ceará (SSPDS-CE). O objetivo central foi responder: **quem são as vítimas, onde e quando os crimes acontecem, e como esse cenário evoluiu ao longo de 16 anos?**

---

## 2. Fonte dos Dados

**Dataset:** CVLI 2009–2025
**Fonte:** SSPDS-CE — [sspds.ce.gov.br](https://www.sspds.ce.gov.br)
**Período:** janeiro de 2009 a dezembro de 2025
**Formato original:** Microsoft Excel (.xlsx) com 3 abas

|         Aba          |                     Descrição                    |      Registros       |
|                      |                                                  |                      |
| CVLI                 | Crimes Violentos Letais Intencionais             | 59.340               |
| Intervenção Policial | Mortes causadas por agentes policiais em serviço | 1.765                |
| Unidade Prisional    | Mortes ocorridas dentro de presídios             | 231                  |
| **Total**            |                                                  | **61.336**           |

### Colunas disponíveis

**CVLI:** Município, AIS, Natureza, Data, Hora, Dia da Semana, Meio Empregado, Gênero, Idade da Vítima, Escolaridade da Vítima, Raça da Vítima

**Intervenção Policial:** Município, AIS, Meio Empregado, Data, Hora, Dia da Semana, Gênero, Idade, Escolaridade, Raça

**Unidade Prisional:** AIS, Data, Hora, Dia da Semana, Gênero, Idade, Escolaridade, Raça

### Limitações encontradas

- **Raça:** 77,7% dos registros constam como "Não Informada", o que limita análises raciais conclusivas
- **Município ausente:** A aba Unidade Prisional não possui campo de município — apenas AIS
- **Natureza ausente:** As abas Intervenção Policial e Unidade Prisional não possuem campo de natureza do crime
- **Formato de data:** O Excel exporta datas no formato `DD/MM/YYYY` — exigiu ajuste no script de importação
- **Separador CSV:** O Excel brasileiro usa ponto e vírgula (`;`) como separador — exigiu configuração manual no DBeaver

---

## 3. Decisões de Modelagem

### Modelo Star Schema

Adotamos o modelo **Star Schema** com uma tabela fato central e 5 tabelas de dimensão. Esse modelo é padrão em análise de dados por facilitar consultas analíticas com JOINs simples e agregações eficientes.

```
dim_municipio ────┐
dim_ais ──────────┤
dim_natureza ─────┼──── fato_ocorrencia (61.336 linhas)
dim_meio ─────────┤
dim_escolaridade ─┘
```

### Unificação das 3 abas

Em vez de criar 3 tabelas separadas (uma por aba do Excel), unificamos tudo em uma única tabela `fato_ocorrencia` com a coluna `tipo_ocorrencia`. Essa decisão permite comparar os 3 tipos de morte em uma única query, simplifica o modelo e não perde informação — colunas ausentes em determinados tipos ficam como NULL.

### Dimensão de Escolaridade com ordem_nivel

A dimensão `dim_escolaridade` possui uma coluna `ordem_nivel` (inteiro de 0 a 8) que representa a hierarquia real dos níveis educacionais. Sem essa coluna, `ORDER BY descricao` ordenaria alfabeticamente, colocando "Não Alfabetizado" no meio da lista. Com `ordem_nivel`, gráficos e relatórios exibem a escolaridade na ordem correta.

### Dia da semana como texto

Optamos por manter `dia_semana` como texto diretamente na tabela fato, sem criar uma tabela de dimensão. São apenas 7 valores fixos sem atributos extras relevantes — criar uma dimensão para isso seria complexidade sem benefício (over-engineering).

### Idade como SMALLINT com NULL

A coluna `idade_vitima` é armazenada como inteiro (`SMALLINT`) com `NULL` quando não informada, em vez de manter o texto "Não Informada". Isso permite cálculos como `AVG()`, `MIN()`, `MAX()` e filtros como `WHERE idade_vitima < 18`.

### Colunas derivadas ano e mes

Adicionamos as colunas `ano` e `mes` como colunas geradas automaticamente a partir de `data_ocorrencia`. Isso evita a necessidade de `EXTRACT()` em toda consulta temporal, melhorando a legibilidade das queries e a performance com índices.

---

## 4. Tratamento dos Dados

### Problemas encontrados e soluções

|                     Problema                    |                                                     Solução                                                         |
|                                                 |                                                                                                                     |
| Datas no formato `DD/MM/YYYY`                   | Ajustado `to_date(s.data, 'DD/MM/YYYY')` nos scripts de INSERT                                                      |
| Separador `;` nos CSVs                          | Configurado manualmente no importador do DBeaver                                                                    |
| Mapeamento automático errado no DBeaver         | Colunas com acentos (Gênero, Raça) e espaços (Meio Empregado) precisaram ser mapeadas manualmente para os
                                                  | nomes corretos da staging                                                                                           |
| Idade como texto misto ("20", "Não Informada")  | Tratado com `CASE WHEN` — valores não numéricos viram `NULL`                                                        |
| Município ausente na aba Unidade Prisional      | `id_municipio = NULL` para esse tipo de ocorrência                                                                  |
| 77,7% de raça "Não Informada"                   | Mantido como valor categórico — mencionado como limitação                                                           |

### Tabelas de Staging

Utilizamos tabelas intermediárias (`staging_cvli`, `staging_intervencao`, `staging_prisional`) para receber os dados brutos dos CSVs sem transformação. O tratamento foi feito em um segundo momento com SQL, separando claramente a etapa de importação da etapa de transformação. Isso é uma boa prática de engenharia de dados — facilita reprocessamento e diagnóstico de problemas.

---

## 5. Perguntas Respondidas

### Pergunta 1 — Como evoluiu o número de mortes violentas no Ceará entre 2009 e 2025?

```sql
SELECT
    ano,
    COUNT(*) AS total_mortes,
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY ano) AS variacao_absoluta,
    ROUND(
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY ano))
        * 100.0 / NULLIF(LAG(COUNT(*)) OVER (ORDER BY ano), 0)
    , 1) AS variacao_percentual
FROM criminalidade.fato_ocorrencia
GROUP BY ano
ORDER BY ano;
```

**Resultado:**

| Ano | Total | Variação |
|---|---|---|
| 2009 | 11.312 | — |
| 2013 | 22.029 | +18,1% |
| 2014 | 22.285 | +1,2% |
| 2017 | 25.864 | **+50,4%** |
| 2019 | 11.424 | **-50,0%** |
| 2020 | 20.341 | +78,1% |
| 2025 | 15.307 | -7,5% |

**Interpretação:** O pico histórico foi em 2017 com 25.864 mortes, representando aumento de 50% em relação a 2016. A maior queda ocorreu em 2019 (-50%), possivelmente relacionada a políticas de segurança pública implementadas no período. O aumento de 78% em 2020 pode estar associado à pandemia e seus efeitos socioeconômicos. Os dados de 2025 ainda estão em consolidação.

---

### Pergunta 2 — Quais municípios concentram mais mortes violentas?

```sql
SELECT
    m.nome AS municipio,
    COUNT(*) AS total_mortes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS perc_do_total
FROM criminalidade.fato_ocorrencia f
JOIN criminalidade.dim_municipio m ON m.id_municipio = f.id_municipio
WHERE f.tipo_ocorrencia = 'CVLI'
GROUP BY m.nome
ORDER BY total_mortes DESC
LIMIT 10;
```

**Resultado:**

| Município | Total | % do Estado |
|---|---|---|
| Fortaleza | 106.280 | 36% |
| Caucaia | 20.260 | 6,86% |
| Maracanaú | 14.125 | 4,78% |
| Juazeiro do Norte | 8.365 | 2,83% |
| Sobral | 6.855 | 2,32% |

**Interpretação:** Fortaleza concentra 36% de todas as mortes violentas do estado — o que reflete sua condição de capital com maior densidade populacional. Os 4 primeiros municípios juntos somam quase 50% do total estadual. É importante notar que volume absoluto favorece cidades maiores — uma análise por taxa por 100 mil habitantes daria uma visão mais justa sobre violência relativa.

---

### Pergunta 3 — Qual o perfil da vítima de homicídio no Ceará?

```sql
-- Por faixa etária
SELECT
    CASE
        WHEN idade_vitima IS NULL THEN '00. Não Informada'
        WHEN idade_vitima < 12 THEN '01. Criança (< 12)'
        WHEN idade_vitima BETWEEN 12 AND 17 THEN '02. Adolescente (12–17)'
        WHEN idade_vitima BETWEEN 18 AND 24 THEN '03. Jovem (18–24)'
        WHEN idade_vitima BETWEEN 25 AND 34 THEN '04. Adulto jovem (25–34)'
        WHEN idade_vitima BETWEEN 35 AND 49 THEN '05. Adulto (35–49)'
        WHEN idade_vitima BETWEEN 50 AND 64 THEN '06. Meia-idade (50–64)'
        ELSE '07. Idoso (65+)'
    END AS faixa_etaria,
    COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS percentual
FROM criminalidade.fato_ocorrencia
WHERE tipo_ocorrencia = 'CVLI'
GROUP BY faixa_etaria
ORDER BY faixa_etaria;
```

**Resultado:**

| Gênero | Total | % |
|---|---|---|
| Masculino | 273.740 | 92,3% |
| Feminino | 22.875 | 7,7% |

| Faixa etária | Total | % |
|---|---|---|
| Jovem (18–24) | 84.305 | 28,4% |
| Adulto jovem (25–34) | 83.410 | 28,1% |
| Adulto (35–49) | 54.715 | 18,4% |

**Interpretação:** O perfil dominante da vítima é homem jovem entre 18 e 34 anos — essa faixa representa 56,5% de todas as vítimas. Esse padrão é consistente com dados nacionais e está associado a vulnerabilidade socioeconômica, envolvimento com tráfico de drogas e ausência de oportunidades. Quanto à raça, 77,7% dos registros constam como "Não Informada", o que impede conclusões sólidas — dos informados, pardos representam a maior parcela (18,3%).

---

### Pergunta 4 — Há padrão temporal nos homicídios?

```sql
SELECT
    dia_semana,
    COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS percentual
FROM criminalidade.fato_ocorrencia
WHERE tipo_ocorrencia = 'CVLI' AND dia_semana IS NOT NULL
GROUP BY dia_semana
ORDER BY CASE dia_semana
    WHEN 'Segunda' THEN 1 WHEN 'Terça' THEN 2 WHEN 'Quarta' THEN 3
    WHEN 'Quinta' THEN 4 WHEN 'Sexta' THEN 5 WHEN 'Sábado' THEN 6
    WHEN 'Domingo' THEN 7 END;
```

**Resultado:**

| Dia | % | Turno | % |
|---|---|---|---|
| Domingo | 18,8% | Noite (18h–00h) | 35,2% |
| Sábado | 17,2% | Madrugada (00h–06h) | 28,1% |
| Segunda | 13,1% | Tarde (12h–18h) | 21,3% |

**Interpretação:** Fim de semana concentra 36% das mortes. Noite e madrugada juntos somam 63% — ou seja, 2 em cada 3 homicídios ocorrem entre 18h e 6h. Esse padrão sugere associação com consumo de álcool, drogas e menor presença policial nesses períodos.

---

### Pergunta 5 — Qual o meio mais usado e como variou ao longo do tempo?

```sql
SELECT
    ano,
    me.descricao AS meio_empregado,
    COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY ano), 1) AS perc_no_ano
FROM criminalidade.fato_ocorrencia f
JOIN criminalidade.dim_meio_empregado me ON me.id_meio = f.id_meio
WHERE f.tipo_ocorrencia = 'CVLI'
GROUP BY ano, me.descricao
ORDER BY ano, total DESC;
```

**Resultado:**

| Ano | Arma de fogo | Arma branca |
|---|---|---|
| 2009 | 74,8% | 16,8% |
| 2012 | 83,2% | 10,8% |
| 2017 | ~85% | ~10% |

**Interpretação:** A arma de fogo dominou todos os anos e sua participação cresceu de 74,8% em 2009 para mais de 83% em 2012. Esse dado reforça a relação direta entre disponibilidade de armas de fogo e violência letal — e dá suporte empírico ao debate sobre políticas de desarmamento.

---

### Pergunta 6 — Como difere o perfil de vítima entre os 3 tipos de morte violenta?

```sql
SELECT
    tipo_ocorrencia,
    COUNT(*) AS total_vitimas,
    ROUND(AVG(idade_vitima), 1) AS media_idade,
    ROUND(SUM(CASE WHEN genero_vitima = 'Masculino' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1) AS perc_masculino,
    ROUND(SUM(CASE WHEN raca_vitima IN ('Parda', 'Preta') THEN 1 ELSE 0 END)
        * 100.0 / NULLIF(SUM(CASE WHEN raca_vitima != 'Não Informada'
        THEN 1 ELSE 0 END), 0), 1) AS perc_negros_informados
FROM criminalidade.fato_ocorrencia
GROUP BY tipo_ocorrencia
ORDER BY total_vitimas DESC;
```

**Resultado:**

| Tipo | Vítimas | Média idade | % Masculino | % Negros |
|---|---|---|---|---|
| CVLI | 59.340 | 29,8 | 92,3% | 87,4% |
| Intervenção Policial | 1.765 | 24,3 | 98,9% | 85,9% |
| Unidade Prisional | 231 | 28,3 | 99,1% | 85,5% |

**Interpretação:** As mortes por intervenção policial têm a vítima mais jovem em média (24,3 anos) e o maior percentual masculino (98,9%). Nos três tipos, o percentual de negros (pardos + pretos) dos registros com raça informada supera 85% — evidenciando uma dimensão racial da violência letal no Ceará. A Unidade Prisional tem quase exclusivamente vítimas masculinas (99,1%), o que reflete o perfil da população carcerária.

---

## 6. Visualizações

*Capturas do dashboard serão adicionadas após a construção no Power BI.*

---

## 7. Conclusão

A análise de 61.336 registros de mortes violentas no Ceará entre 2009 e 2025 revela padrões consistentes e preocupantes.

**O perfil da vítima é altamente específico:** homem, jovem entre 18 e 34 anos, morto à noite ou na madrugada, no fim de semana, por arma de fogo. Esse perfil se manteve estável ao longo de 16 anos, independentemente das variações no volume total de crimes.

**A concentração geográfica é extrema:** Fortaleza e sua região metropolitana (Caucaia, Maracanaú) respondem por quase metade de todas as mortes do estado, o que indica que políticas de segurança precisam ser especialmente focadas nessa região.

**A evolução temporal mostra alta volatilidade:** o estado passou por um pico crítico em 2017 (+50% em relação ao ano anterior) seguido de uma queda expressiva em 2019 (-50%), sugerindo que intervenções de segurança pública têm impacto real — mas os ganhos não se sustentaram, como mostra o aumento de 2020.

**A arma de fogo é o instrumento dominante** em mais de 74% dos casos desde 2009, com tendência de crescimento. Isso posiciona o controle de armas como variável central em qualquer estratégia de redução da violência letal no estado.

Por fim, a alta proporção de raça "Não Informada" (77,7%) nos registros é uma limitação séria dos dados — melhorar o preenchimento desse campo nos boletins de ocorrência seria fundamental para análises mais precisas sobre a dimensão racial da violência.