-- =====================================================================
-- PORTAL DO ALUNO — BASE DE DADOS
-- =====================================================================
-- Dialeto: SQLite (funciona também em MySQL/PostgreSQL com pequenos
-- ajustes: trocar INTEGER PRIMARY KEY AUTOINCREMENT por
-- AUTO_INCREMENT/SERIAL, e datetime('now') pelo equivalente do motor).
--
-- Esta base de dados normaliza o estado em memória (objeto `S`) do
-- protótipo HTML "Portal do Aluno — Simulação" em tabelas relacionais,
-- para que o projeto possa persistir dados reais em vez de um objeto
-- JavaScript que se perde ao recarregar a página.
--
-- Organização:
--   1. Escolas e a sua configuração (matrícula, propinas, cursos...)
--   2. Estrutura académica (turmas, disciplinas, atribuições)
--   3. Utilizadores (alunos, encarregados, professores, staff)
--   4. Avaliações e notas / pautas
--   5. Matrículas, propinas e documentos
--   6. Presenças, calendário e horários
--   7. Mural (posts), chat e recursos (livros/vídeos)
--   8. Configurações e dados de apoio
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- 1. ESCOLAS
-- ---------------------------------------------------------------------

CREATE TABLE escolas (
  id                        INTEGER PRIMARY KEY AUTOINCREMENT,
  slug                      TEXT NOT NULL UNIQUE,
  nome                      TEXT NOT NULL,
  area                      TEXT,
  info                      TEXT,
  regras                    TEXT,
  whatsapp                  TEXT,
  matricula_valor_kz        INTEGER,
  matricula_periodo         TEXT,
  propinas_valor_kz         INTEGER,
  propinas_vencimento_dia   INTEGER,
  propinas_multa            TEXT,
  criado_em                 TEXT DEFAULT (datetime('now'))
);

CREATE TABLE cursos (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  nome        TEXT NOT NULL,
  UNIQUE (escola_id, nome)
);

-- Classes/cursos oferecidos por cada escola, com o valor mensal (o que
-- aparecia como texto único "10ª classe — 25.000 Kz/mês").
CREATE TABLE classes_oferecidas (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id         INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  classe            TEXT NOT NULL,
  curso_id          INTEGER REFERENCES cursos(id) ON DELETE SET NULL,
  valor_mensal_kz   INTEGER
);

CREATE TABLE matricula_documentos_exigidos (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  documento   TEXT NOT NULL
);

CREATE TABLE matricula_campos_formulario (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  campo       TEXT NOT NULL,
  ordem       INTEGER NOT NULL DEFAULT 0
);

-- Propina por classe/curso (quando difere do valor geral da escola).
CREATE TABLE propinas_por_classe (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id         INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  classe            TEXT NOT NULL,
  curso_id          INTEGER REFERENCES cursos(id) ON DELETE SET NULL,
  valor_mensal_kz   INTEGER NOT NULL
);

-- Classes/cursos para os quais existe "confirmação de vaga".
CREATE TABLE confirmacao_classes (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  classe      TEXT NOT NULL,
  curso_id    INTEGER REFERENCES cursos(id) ON DELETE SET NULL
);

CREATE TABLE tipos_documento (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  nome        TEXT NOT NULL
);

CREATE TABLE servicos_escola (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  nome        TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. ESTRUTURA ACADÉMICA
-- ---------------------------------------------------------------------

CREATE TABLE turmas (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  nome        TEXT NOT NULL,        -- ex: "12ª B"
  classe      TEXT NOT NULL,        -- ex: "12ª classe"
  curso_id    INTEGER REFERENCES cursos(id) ON DELETE SET NULL,
  sala        TEXT,
  periodo     TEXT,                 -- Manhã | Tarde
  UNIQUE (escola_id, nome)
);

CREATE TABLE disciplinas (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  nome        TEXT NOT NULL,
  classe      TEXT,
  curso_id    INTEGER REFERENCES cursos(id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------
-- 3. UTILIZADORES
-- ---------------------------------------------------------------------

CREATE TABLE utilizadores (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id         INTEGER REFERENCES escolas(id) ON DELETE CASCADE,
  tipo              TEXT NOT NULL CHECK (tipo IN (
                      'aluno', 'encarregado', 'professor',
                      'direcao', 'secretaria', 'administrativo'
                    )),
  nome              TEXT NOT NULL,
  email             TEXT,
  telefone          TEXT,
  codigo_acesso     TEXT,           -- login sem email/telefone (S.semEmail)
  password_hash     TEXT,
  departamento      TEXT,           -- administrativa | pedagogica (staff)
  cargo             TEXT,           -- Diretor(a), Secretária, etc.
  criado_em         TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_utilizadores_escola ON utilizadores(escola_id);

-- Ficha adicional só para alunos.
CREATE TABLE alunos_ficha (
  utilizador_id           INTEGER PRIMARY KEY REFERENCES utilizadores(id) ON DELETE CASCADE,
  classe                  TEXT,
  turma_id                INTEGER REFERENCES turmas(id) ON DELETE SET NULL,
  sala                    TEXT,
  periodo                 TEXT,
  nome_pai                TEXT,
  nome_mae                TEXT,
  telefone_encarregado    TEXT
);

-- Vínculo encarregado <-> aluno (um encarregado pode acompanhar vários
-- educandos).
CREATE TABLE encarregado_aluno (
  encarregado_id  INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  aluno_id        INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  PRIMARY KEY (encarregado_id, aluno_id)
);

-- Quem leciona o quê, onde e quando (feito pela secretaria/direção).
CREATE TABLE professor_disciplina_turma (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  professor_id    INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  disciplina_id   INTEGER REFERENCES disciplinas(id) ON DELETE SET NULL,
  turma_id        INTEGER NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  sala            TEXT,
  periodo         TEXT
);

-- ---------------------------------------------------------------------
-- 4. AVALIAÇÕES, NOTAS E PAUTAS
-- ---------------------------------------------------------------------

CREATE TABLE avaliacoes (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  turma_id        INTEGER NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  disciplina_id   INTEGER REFERENCES disciplinas(id) ON DELETE SET NULL,
  nome            TEXT NOT NULL,     -- "1º Teste", "1º Trimestre"...
  data            TEXT
);

-- Escala (0-10 ou 0-20) é derivada da classe da turma pela aplicação;
-- guardamos aqui para não depender de lógica externa ao consultar.
CREATE TABLE notas (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  avaliacao_id    INTEGER NOT NULL REFERENCES avaliacoes(id) ON DELETE CASCADE,
  aluno_id        INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  nota            REAL NOT NULL,
  escala          INTEGER NOT NULL CHECK (escala IN (10, 20)),
  situacao        TEXT,              -- Aprovado | Reprovado | Em recuperação
  UNIQUE (avaliacao_id, aluno_id)
);

CREATE INDEX idx_notas_aluno ON notas(aluno_id);

CREATE TABLE pautas (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  turma_id        INTEGER NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  ano             TEXT NOT NULL,
  publicada_em    TEXT DEFAULT (datetime('now'))
);

CREATE TABLE pauta_resultados (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  pauta_id    INTEGER NOT NULL REFERENCES pautas(id) ON DELETE CASCADE,
  aluno_id    INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  situacao    TEXT NOT NULL,
  UNIQUE (pauta_id, aluno_id)
);

-- Plano de aulas / conteúdos por disciplina (S.plano).
CREATE TABLE plano_aulas (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  turma_id        INTEGER NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  disciplina_id   INTEGER REFERENCES disciplinas(id) ON DELETE SET NULL,
  topico          TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 5. MATRÍCULAS, PROPINAS E DOCUMENTOS
-- ---------------------------------------------------------------------

-- Candidaturas de matrícula submetidas (S.matriculaDraft e histórico).
-- `dados_extra` guarda em JSON os campos dinâmicos definidos por
-- matricula_campos_formulario (cada escola pede campos diferentes).
CREATE TABLE matriculas (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id           INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  aluno_id            INTEGER REFERENCES utilizadores(id) ON DELETE SET NULL,
  classe              TEXT NOT NULL,
  curso_id            INTEGER REFERENCES cursos(id) ON DELETE SET NULL,
  dados_extra_json    TEXT,
  estado              TEXT NOT NULL DEFAULT 'pendente'
                        CHECK (estado IN ('pendente', 'confirmada', 'rejeitada')),
  criado_em           TEXT DEFAULT (datetime('now'))
);

CREATE TABLE propinas_mensais (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  aluno_id    INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  ano         INTEGER NOT NULL,
  mes         TEXT NOT NULL,
  status      TEXT NOT NULL CHECK (status IN ('ok', 'atraso', 'pendente')),
  valor_kz    INTEGER,
  pago_em     TEXT,
  UNIQUE (aluno_id, ano, mes)
);

-- Ficheiros que a escola envia diretamente para a pasta do aluno
-- ("Meus Documentos" — diferente do pedido feito pelo aluno).
CREATE TABLE documentos_aluno (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  aluno_id      INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  nome_arquivo  TEXT NOT NULL,
  url           TEXT,
  enviado_em    TEXT DEFAULT (datetime('now'))
);

-- Pedidos de documentos feitos pelo aluno/encarregado.
CREATE TABLE pedidos_documentos (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  aluno_id      INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  tipo          TEXT NOT NULL,
  estado        TEXT NOT NULL DEFAULT 'Solicitado'
                  CHECK (estado IN ('Solicitado', 'Em análise', 'Pronto', 'Entregue')),
  criado_em     TEXT DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- 6. PRESENÇAS, CALENDÁRIO E HORÁRIOS
-- ---------------------------------------------------------------------

CREATE TABLE presencas (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  turma_id    INTEGER NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  aluno_id    INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  data        TEXT NOT NULL DEFAULT (date('now')),
  status      TEXT NOT NULL CHECK (status IN ('presente', 'falta', 'atraso')),
  UNIQUE (turma_id, aluno_id, data)
);

CREATE INDEX idx_presencas_aluno_data ON presencas(aluno_id, data);

-- Resumo diário por turma (S.attendanceHistory: "28 presentes · 2 faltas").
CREATE TABLE presencas_resumo (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  turma_id    INTEGER NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  data        TEXT NOT NULL,
  presentes   INTEGER NOT NULL DEFAULT 0,
  faltas      INTEGER NOT NULL DEFAULT 0,
  atrasos     INTEGER NOT NULL DEFAULT 0,
  UNIQUE (turma_id, data)
);

CREATE TABLE eventos_calendario (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  nome        TEXT NOT NULL,
  data        TEXT NOT NULL
);

CREATE TABLE horario_aulas (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  turma_id        INTEGER NOT NULL REFERENCES turmas(id) ON DELETE CASCADE,
  disciplina_id   INTEGER REFERENCES disciplinas(id) ON DELETE SET NULL,
  dia_semana      TEXT NOT NULL,   -- Segunda, Terça, ...
  hora            TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 7. MURAL (POSTS), CHAT E RECURSOS
-- ---------------------------------------------------------------------

CREATE TABLE publicacoes (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
  autor_id    INTEGER REFERENCES utilizadores(id) ON DELETE SET NULL, -- NULL = publicado pela escola
  tag         TEXT,               -- Aviso | Evento | Matrícula | Pauta ...
  corpo       TEXT NOT NULL,
  criado_em   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_publicacoes_escola ON publicacoes(escola_id);

CREATE TABLE curtidas (
  publicacao_id   INTEGER NOT NULL REFERENCES publicacoes(id) ON DELETE CASCADE,
  utilizador_id   INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  PRIMARY KEY (publicacao_id, utilizador_id)
);

-- Livros e vídeos: "escola" (carregados pela própria escola) ou
-- "portal" (biblioteca geral do Portal do Aluno).
CREATE TABLE recursos (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id           INTEGER REFERENCES escolas(id) ON DELETE CASCADE, -- NULL = recurso do portal
  tipo                TEXT NOT NULL CHECK (tipo IN ('livro', 'video')),
  origem              TEXT NOT NULL CHECK (origem IN ('escola', 'portal')),
  titulo              TEXT NOT NULL,
  autor_ou_detalhes   TEXT,
  classe              TEXT
);

CREATE TABLE conversas (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  escola_id   INTEGER REFERENCES escolas(id) ON DELETE CASCADE,
  nome        TEXT,
  tipo        TEXT NOT NULL CHECK (tipo IN ('turma', 'privada'))
);

CREATE TABLE participantes_conversa (
  conversa_id     INTEGER NOT NULL REFERENCES conversas(id) ON DELETE CASCADE,
  utilizador_id   INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  PRIMARY KEY (conversa_id, utilizador_id)
);

CREATE TABLE mensagens_chat (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  conversa_id   INTEGER NOT NULL REFERENCES conversas(id) ON DELETE CASCADE,
  autor_id      INTEGER REFERENCES utilizadores(id) ON DELETE SET NULL,
  corpo         TEXT NOT NULL,
  enviado_em    TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_mensagens_conversa ON mensagens_chat(conversa_id);

-- ---------------------------------------------------------------------
-- 8. CONFIGURAÇÕES E DADOS DE APOIO
-- ---------------------------------------------------------------------

-- Checklist genérica ("Confirmar matrícula", "Confirmar inscrição na
-- turma"...) associada a um utilizador.
CREATE TABLE confirmacoes_pendentes (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  utilizador_id   INTEGER NOT NULL REFERENCES utilizadores(id) ON DELETE CASCADE,
  descricao       TEXT NOT NULL,
  status          TEXT NOT NULL CHECK (status IN ('ok', 'warn'))
);

CREATE TABLE configuracoes_utilizador (
  utilizador_id   INTEGER PRIMARY KEY REFERENCES utilizadores(id) ON DELETE CASCADE,
  notificacoes    INTEGER NOT NULL DEFAULT 1,
  modo_escuro     INTEGER NOT NULL DEFAULT 1,
  som_chat        INTEGER NOT NULL DEFAULT 0
);

-- =====================================================================
-- DADOS DE EXEMPLO (equivalentes aos valores iniciais do objeto `S`)
-- =====================================================================

INSERT INTO escolas (slug, nome, area, info, regras, whatsapp, matricula_valor_kz, matricula_periodo, propinas_valor_kz, propinas_vencimento_dia, propinas_multa) VALUES
('nova-esperanca', 'Colégio Nova Esperança', 'Ensino geral · 7ª à 12ª classe', 'Escola de ensino geral, da 7ª à 12ª classe, com turmas de Ciências Físicas e Humanidades. A funcionar desde 2005.', 'Uniforme obrigatório. Tolerância de 10 minutos na entrada.', '+244 900 000 000', 15000, '1 de agosto a 15 de setembro', 25000, 10, '2.000 Kz após 5 dias de atraso'),
('info-huambo', 'Instituto Técnico de Informática do Huambo', 'Informática e Programação', 'Formação técnico-profissional em informática, redes e programação, com laboratórios equipados.', 'Presença mínima de 75% para exame final.', '+244 911 111 111', 18000, '5 de agosto a 20 de setembro', 22000, 5, '1.500 Kz após 3 dias de atraso'),
('enfermagem-bom-samaritano', 'Escola de Enfermagem Bom Samaritano', 'Enfermagem e Saúde', 'Formação de técnicos de enfermagem com estágio clínico incluído.', 'Uniforme e crachá obrigatórios durante o estágio.', '+244 922 222 222', 20000, '1 a 30 de agosto', 28000, 10, '2.500 Kz após 5 dias de atraso'),
('politecnico-comercio', 'Colégio Politécnico do Comércio', 'Gestão, Contabilidade e Comércio', 'Ensino técnico-profissional nas áreas de gestão, contabilidade e comércio internacional.', 'Trabalhos entregues fora do prazo têm desconto de 20%.', '+244 933 333 333', 16000, '1 de agosto a 10 de setembro', 23000, 8, '2.000 Kz após 5 dias de atraso'),
('mecanica-industrial', 'Instituto Superior de Mecânica Industrial', 'Mecânica e Eletricidade', 'Formação técnica em mecânica industrial, eletricidade e manutenção de máquinas.', 'Uso obrigatório de equipamento de proteção na oficina.', '+244 944 444 444', 19000, '1 a 25 de agosto', 26000, 10, '2.000 Kz após 5 dias de atraso'),
('belas-artes-luanda', 'Colégio Belas Artes de Luanda', 'Artes Visuais e Design', 'Escola de artes visuais, design gráfico e ilustração, com ateliers próprios.', 'Material de desenho não incluído na propina.', '+244 955 555 555', 17000, '1 de agosto a 15 de setembro', 25000, 10, '2.000 Kz após 5 dias de atraso'),
('agraria-terra-fertil', 'Escola Agrária Terra Fértil', 'Agropecuária', 'Formação técnica em agropecuária, com terreno experimental próprio.', 'Aulas práticas exigem bota e roupa apropriada.', '+244 966 666 666', 14000, '1 a 30 de agosto', 21000, 10, '1.500 Kz após 5 dias de atraso'),
('maritimo-costa-azul', 'Colégio Marítimo Costa Azul', 'Náutica e Pesca', 'Formação técnica em náutica, pesca e mecânica naval, junto à costa.', 'Exame médico anual obrigatório.', '+244 977 777 777', 18000, '1 a 30 de agosto', 24000, 10, '2.000 Kz após 5 dias de atraso');

INSERT INTO cursos (escola_id, nome) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Ciências Físicas e Biológicas'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Humanidades e Ciências Sociais');

INSERT INTO classes_oferecidas (escola_id, classe, valor_mensal_kz) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '10ª classe', 25000),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '11ª classe', 27000),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '12ª classe', 30000);

INSERT INTO propinas_por_classe (escola_id, classe, curso_id, valor_mensal_kz) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '10ª classe', (SELECT id FROM cursos WHERE nome = 'Ciências Físicas e Biológicas'), 25000),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '10ª classe', (SELECT id FROM cursos WHERE nome = 'Humanidades e Ciências Sociais'), 24000);

INSERT INTO turmas (escola_id, nome, classe, sala, periodo) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '6ª A', '6ª classe', 'Sala 1', 'Tarde'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '12ª B', '12ª classe', 'Sala 4', 'Manhã');

INSERT INTO disciplinas (escola_id, nome, classe) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Matemática', '12ª classe'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Física', '12ª classe'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Todas as disciplinas', '6ª classe');

INSERT INTO utilizadores (escola_id, tipo, nome, cargo) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'professor', 'Prof. Amaro', NULL),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'professor', 'Prof. Isabel', NULL),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'aluno', 'Ana Luísa', NULL),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'aluno', 'Marcos B.', NULL);

INSERT INTO alunos_ficha (utilizador_id, classe, turma_id, sala, periodo) VALUES
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), '6ª classe', (SELECT id FROM turmas WHERE nome = '6ª A'), 'Sala 1', 'Tarde'),
((SELECT id FROM utilizadores WHERE nome = 'Marcos B.'), '12ª classe', (SELECT id FROM turmas WHERE nome = '12ª B'), 'Sala 4', 'Manhã');

INSERT INTO professor_disciplina_turma (professor_id, disciplina_id, turma_id, sala, periodo) VALUES
((SELECT id FROM utilizadores WHERE nome = 'Prof. Amaro'), (SELECT id FROM disciplinas WHERE nome = 'Matemática'), (SELECT id FROM turmas WHERE nome = '12ª B'), 'Sala 4', 'Manhã'),
((SELECT id FROM utilizadores WHERE nome = 'Prof. Isabel'), (SELECT id FROM disciplinas WHERE nome = 'Física'), (SELECT id FROM turmas WHERE nome = '12ª B'), 'Sala 4', 'Manhã'),
((SELECT id FROM utilizadores WHERE nome = 'Prof. Amaro'), (SELECT id FROM disciplinas WHERE nome = 'Todas as disciplinas'), (SELECT id FROM turmas WHERE nome = '6ª A'), 'Sala 1', 'Tarde');

INSERT INTO avaliacoes (turma_id, disciplina_id, nome) VALUES
((SELECT id FROM turmas WHERE nome = '12ª B'), (SELECT id FROM disciplinas WHERE nome = 'Matemática'), '1º Teste'),
((SELECT id FROM turmas WHERE nome = '12ª B'), (SELECT id FROM disciplinas WHERE nome = 'Física'), '1º Teste'),
((SELECT id FROM turmas WHERE nome = '6ª A'), (SELECT id FROM disciplinas WHERE nome = 'Todas as disciplinas'), '1º Trimestre');

INSERT INTO notas (avaliacao_id, aluno_id, nota, escala, situacao) VALUES
((SELECT id FROM avaliacoes WHERE nome = '1º Teste' AND disciplina_id = (SELECT id FROM disciplinas WHERE nome = 'Matemática')), (SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 16, 20, 'Aprovado'),
((SELECT id FROM avaliacoes WHERE nome = '1º Teste' AND disciplina_id = (SELECT id FROM disciplinas WHERE nome = 'Matemática')), (SELECT id FROM utilizadores WHERE nome = 'Marcos B.'), 9, 20, 'Em recuperação'),
((SELECT id FROM avaliacoes WHERE nome = '1º Teste' AND disciplina_id = (SELECT id FROM disciplinas WHERE nome = 'Física')), (SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 14, 20, 'Aprovado'),
((SELECT id FROM avaliacoes WHERE nome = '1º Trimestre'), (SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 8, 10, 'Em recuperação');

INSERT INTO pautas (turma_id, ano, publicada_em) VALUES
((SELECT id FROM turmas WHERE nome = '12ª B'), '2026', datetime('now', '-2 days'));

INSERT INTO pauta_resultados (pauta_id, aluno_id, situacao) VALUES
((SELECT id FROM pautas WHERE ano = '2026'), (SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Aprovado'),
((SELECT id FROM pautas WHERE ano = '2026'), (SELECT id FROM utilizadores WHERE nome = 'Marcos B.'), 'Em recuperação');

INSERT INTO documentos_aluno (aluno_id, nome_arquivo) VALUES
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Declaração escolar.pdf'),
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Boletim 2026.pdf');

INSERT INTO pedidos_documentos (aluno_id, tipo, estado) VALUES
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Certificado', 'Entregue'),
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Declaração', 'Pronto'),
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Boletim de notas', 'Em análise'),
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Comprovativo de matrícula', 'Solicitado');

INSERT INTO presencas (turma_id, aluno_id, status) VALUES
((SELECT id FROM turmas WHERE nome = '12ª B'), (SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'presente'),
((SELECT id FROM turmas WHERE nome = '12ª B'), (SELECT id FROM utilizadores WHERE nome = 'Marcos B.'), 'presente');

INSERT INTO presencas_resumo (turma_id, data, presentes, faltas) VALUES
((SELECT id FROM turmas WHERE nome = '12ª B'), '2026-08-07', 28, 2),
((SELECT id FROM turmas WHERE nome = '12ª B'), '2026-07-31', 27, 3);

INSERT INTO eventos_calendario (escola_id, nome, data) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Início do 2º trimestre', '10 ago'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Feira de ciências', '22 ago'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Conselho de turma', '29 ago'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Fim do 2º trimestre', '18 dez');

INSERT INTO horario_aulas (turma_id, disciplina_id, dia_semana, hora) VALUES
((SELECT id FROM turmas WHERE nome = '12ª B'), (SELECT id FROM disciplinas WHERE nome = 'Matemática'), 'Segunda', '08:00'),
((SELECT id FROM turmas WHERE nome = '12ª B'), (SELECT id FROM disciplinas WHERE nome = 'Física'), 'Segunda', '09:30');

INSERT INTO publicacoes (escola_id, tag, corpo, criado_em) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Aviso', 'As aulas do 2º trimestre retomam na segunda-feira, dia 10. Os alunos devem trazer o material completo desde o primeiro dia.', datetime('now', '-2 hours')),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Evento', 'Feira de ciências marcada para dia 22, no pátio principal. Turmas do 9º ao 12º ano apresentam os seus projetos.', datetime('now', '-1 day')),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Matrícula', 'As matrículas para o ano letivo 2026/2027 já estão abertas. Consulta o módulo de Matrículas para mais detalhes.', datetime('now', '-3 days')),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Pauta', 'As pautas do 1º trimestre já foram publicadas. Alunos e encarregados podem consultá-las no módulo Pautas.', datetime('now', '-5 days'));

INSERT INTO recursos (escola_id, tipo, origem, titulo, autor_ou_detalhes, classe) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'livro', 'escola', 'Matemática 10ª classe', 'Dept. de Matemática', '10ª classe'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'livro', 'escola', 'Manual de Física', 'Dept. de Ciências', '10ª classe'),
(NULL, 'livro', 'portal', 'Gramática Essencial', 'Portal do Aluno', NULL),
(NULL, 'livro', 'portal', 'Introdução à Química', 'Portal do Aluno', NULL),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'video', 'escola', 'Equações do 2º grau', 'Prof. Amaro', '6ª classe'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'video', 'escola', 'Leis de Newton', 'Prof. Isabel', '12ª classe');

INSERT INTO conversas (escola_id, nome, tipo) VALUES
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '12ª B', 'turma'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), '6ª A', 'turma'),
((SELECT id FROM escolas WHERE slug = 'nova-esperanca'), 'Encarregado — Ana Luísa', 'privada');

INSERT INTO mensagens_chat (conversa_id, autor_id, corpo) VALUES
(1, NULL, 'Boa tarde! Alguém tem os apontamentos de Física de hoje?'),
(1, (SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Tenho sim, envio já a foto do caderno.'),
(1, NULL, 'Obrigada! 🙏'),
(2, NULL, 'Pessoal, reunião de turma amanhã às 14h.'),
(3, NULL, 'Boa tarde, professor. Como está o meu educando este trimestre?'),
(3, (SELECT id FROM utilizadores WHERE nome = 'Prof. Amaro'), 'Boa tarde! Está a ir muito bem, sobretudo em Matemática.');

INSERT INTO confirmacoes_pendentes (utilizador_id, descricao, status) VALUES
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Confirmar matrícula', 'warn'),
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Confirmar inscrição na turma', 'ok'),
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 'Confirmar entrega de documento pedido', 'warn');

INSERT INTO configuracoes_utilizador (utilizador_id, notificacoes, modo_escuro, som_chat) VALUES
((SELECT id FROM utilizadores WHERE nome = 'Ana Luísa'), 1, 1, 0);
