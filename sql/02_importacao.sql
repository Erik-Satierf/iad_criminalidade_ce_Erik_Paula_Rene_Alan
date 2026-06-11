-- ============================================================
-- ARQUIVO: 02_importacao.sql
-- DESCRIÇÃO: Carga dos dados nas tabelas
-- ORDEM DE EXECUÇÃO: Sempre dimensões primeiro, fato depois.
--   Por quê? A tabela fato tem chaves estrangeiras (FK) que
--   referenciam as dimensões. Se inserir a fato antes, o banco
--   rejeita com erro de integridade referencial.
-- ============================================================

SET search_path TO criminalidade;


-- ============================================================
-- PASSO 1 — POPULAR AS DIMENSÕES
-- Dados fixos e conhecidos — inserimos manualmente via SQL.
-- ============================================================

-- ------------------------------------------------------------
-- Municípios (184 municípios do Ceará presentes nos dados)
-- Inserimos apenas os que aparecem no dataset, não todos do CE.
-- ------------------------------------------------------------
INSERT INTO criminalidade.dim_municipio (nome) VALUES
('Abaiara'), ('Acaraú'), ('Acopiara'), ('Aiuaba'), ('Alcântaras'),
('Altaneira'), ('Alto Santo'), ('Amontada'), ('Antonina do Norte'), ('Apuiarés'),
('Aquiraz'), ('Aracati'), ('Aracoiaba'), ('Ararendá'), ('Araripe'),
('Aratuba'), ('Arneiroz'), ('Assaré'), ('Aurora'), ('Baixio'),
('Banabuiú'), ('Barbalha'), ('Barreira'), ('Barro'), ('Barroquinha'),
('Baturité'), ('Beberibe'), ('Bela Cruz'), ('Boa Viagem'), ('Brejo Santo'),
('Camocim'), ('Campos Sales'), ('Canindé'), ('Capistrano'), ('Caridade'),
('Cariré'), ('Caririaçu'), ('Cariús'), ('Carnaubal'), ('Cascavel'),
('Catarina'), ('Catunda'), ('Caucaia'), ('Cedro'), ('Chaval'),
('Choró'), ('Chorozinho'), ('Coreaú'), ('Crateús'), ('Crato'),
('Croatá'), ('Cruz'), ('Deputado Irapuan Pinheiro'), ('Ererê'), ('Eusébio'),
('Farias Brito'), ('Forquilha'), ('Fortaleza'), ('Fortim'), ('Frecheirinha'),
('General Sampaio'), ('Graça'), ('Granja'), ('Granjeiro'), ('Groaíras'),
('Guaiúba'), ('Guaraciaba do Norte'), ('Guaramiranga'), ('Hidrolândia'), ('Horizonte'),
('Ibaretama'), ('Ibiapina'), ('Ibicuitinga'), ('Icapuí'), ('Icó'),
('Iguatu'), ('Independência'), ('Ipaporanga'), ('Ipaumirim'), ('Ipu'),
('Ipueiras'), ('Iracema'), ('Irauçuba'), ('Itaiçaba'), ('Itaitinga'),
('Itapajé'), ('Itapipoca'), ('Itapiúna'), ('Itarema'), ('Itatira'),
('Jaguaretama'), ('Jaguaribara'), ('Jaguaribe'), ('Jaguaruana'), ('Jardim'),
('Jati'), ('Jijoca de Jericoacoara'), ('Juazeiro do Norte'), ('Jucás'), ('Lavras da Mangabeira'),
('Limoeiro do Norte'), ('Madalena'), ('Maracanaú'), ('Maranguape'), ('Massapê'),
('Mauriti'), ('Meruoca'), ('Milagres'), ('Milhã'), ('Miraíma'),
('Missão Velha'), ('Mombaça'), ('Monsenhor Tabosa'), ('Morada Nova'), ('Moraújo'),
('Morrinhos'), ('Mucambo'), ('Mulungu'), ('Nova Olinda'), ('Nova Russas'),
('Novo Oriente'), ('Ocara'), ('Orós'), ('Pacajus'), ('Pacatuba'),
('Pacoti'), ('Pacujá'), ('Palhano'), ('Palmácia'), ('Paracuru'),
('Paraipaba'), ('Parambu'), ('Paramoti'), ('Pedra Branca'), ('Penaforte'),
('Pentecoste'), ('Pereiro'), ('Pindoretama'), ('Piquet Carneiro'), ('Pires Ferreira'),
('Poranga'), ('Porteiras'), ('Potengi'), ('Potiretama'), ('Quiterianópolis'),
('Quixadá'), ('Quixelô'), ('Quixeramobim'), ('Quixeré'), ('Redenção'),
('Reriutaba'), ('Russas'), ('Saboeiro'), ('Salitre'), ('Santa Quitéria'),
('Santana do Acaraú'), ('Santana do Cariri'), ('São Benedito'), ('São Gonçalo do Amarante'), ('São João do Jaguaribe'),
('São Luís do Curu'), ('Senador Pompeu'), ('Senador Sá'), ('Sobral'), ('Solonópole'),
('Tabuleiro do Norte'), ('Tamboril'), ('Tarrafas'), ('Tauá'), ('Tejuçuoca'),
('Tianguá'), ('Trairi'), ('Tururu'), ('Ubajara'), ('Umari'),
('Umirim'), ('Uruburetama'), ('Uruoca'), ('Varjota'), ('Várzea Alegre'),
('Viçosa do Ceará');

-- ------------------------------------------------------------
-- AIS — Áreas Integradas de Segurança Pública
-- ------------------------------------------------------------
INSERT INTO criminalidade.dim_ais (codigo) VALUES
('AIS 01'), ('AIS 02'), ('AIS 03'), ('AIS 04'), ('AIS 05'),
('AIS 06'), ('AIS 07'), ('AIS 08'), ('AIS 09'), ('AIS 10'),
('AIS 11'), ('AIS 12'), ('AIS 13'), ('AIS 14'), ('AIS 15'),
('AIS 16'), ('AIS 17'), ('AIS 18'), ('AIS 19'), ('AIS 20'),
('AIS 21'), ('AIS 22'), ('AIS 23'), ('AIS 24'), ('AIS 25'),
('AIS 26'), ('AIS 27'), ('AIS 28'), ('AIS 29'), ('AIS 30'),
('AIS 31'), ('AIS 32'), ('AIS 33'), ('AIS 34'),
('AIS Não Identificada (Caucaia)'),
('AIS Não Identificada (Fortaleza)');

-- ------------------------------------------------------------
-- Natureza do crime (apenas CVLI possui esse campo)
-- ------------------------------------------------------------
INSERT INTO criminalidade.dim_natureza (descricao) VALUES
('HOMICIDIO DOLOSO'),
('FEMINICÍDIO'),
('LESAO CORPORAL SEGUIDA DE MORTE'),
('ROUBO SEGUIDO DE MORTE (LATROCINIO)');

-- ------------------------------------------------------------
-- Meio empregado
-- ------------------------------------------------------------
INSERT INTO criminalidade.dim_meio_empregado (descricao) VALUES
('Arma de fogo'),
('Arma branca'),
('Outros meios'),
('Meio não informado');

-- ------------------------------------------------------------
-- Escolaridade com ordem_nivel
-- A ordem representa a hierarquia real do nível educacional.
-- Isso permite ORDER BY ordem_nivel em relatórios e gráficos.
-- 0 = Não Informada (tratado separado, não é nível educacional)
-- ------------------------------------------------------------
INSERT INTO criminalidade.dim_escolaridade (descricao, ordem_nivel) VALUES
('Não Informada',                  0),
('Não Alfabetizado',               1),
('Alfabetizado',                   2),
('Ensino Fundamental Incompleto',  3),
('Ensino Fundamental Completo',    4),
('Ensino Médio Incompleto',        5),
('Ensino Médio Completo',          6),
('Superior Incompleto',            7),
('Superior Completo',              8);


-- ============================================================
-- PASSO 2 — IMPORTAR OS DADOS DO EXCEL COMO CSV
-- ============================================================

CREATE TABLE IF NOT EXISTS criminalidade.staging_cvli (
    municipio          TEXT,
    ais                TEXT,
    natureza           TEXT,
    data               TEXT,  -- TEXT porque o CSV pode trazer formato variado
    hora               TEXT,
    dia_semana         TEXT,
    meio_empregado     TEXT,
    genero             TEXT,
    idade_vitima       TEXT,  -- TEXT porque vem misturado: "20", "Não Informada"
    escolaridade       TEXT,
    raca               TEXT
);

CREATE TABLE IF NOT EXISTS criminalidade.staging_intervencao (
    municipio      TEXT,
    ais            TEXT,
    meio_empregado TEXT,
    data           TEXT,
    hora           TEXT,
    dia_semana     TEXT,
    genero         TEXT,
    idade          TEXT,
    escolaridade   TEXT,
    raca           TEXT
);

CREATE TABLE IF NOT EXISTS criminalidade.staging_prisional (
    ais          TEXT,
    data         TEXT,
    hora         TEXT,
    dia_semana   TEXT,
    genero       TEXT,
    idade        TEXT,
    escolaridade TEXT,
    raca         TEXT
);

-- COPY criminalidade.staging_cvli
-- FROM 'C:/dados/cvli.csv'
-- WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

-- COPY criminalidade.staging_intervencao
-- FROM 'C:/dados/intervencao_policial.csv'
-- WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

-- COPY criminalidade.staging_prisional
-- FROM 'C:/dados/unidade_prisional.csv'
-- WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');