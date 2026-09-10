const { all, get, run } = require('../db');

module.exports = function registerUtilizadoresRoutes(router) {
  // POST /api/login
  // Login simplificado: por email OU código de acesso, dentro de uma escola.
  // (Num sistema real isto teria password com hash + sessão/JWT — aqui fica
  // o essencial para ligar o ecrã de login do protótipo à base de dados.)
  router.post('/api/login', (req, res) => {
    const { escola_id, email, codigo_acesso } = req.body;
    if (!escola_id || (!email && !codigo_acesso)) {
      return res.status(400).json({ erro: 'escola_id e (email ou codigo_acesso) são obrigatórios' });
    }
    const utilizador = email
      ? get('SELECT * FROM utilizadores WHERE escola_id = ? AND email = ?', [escola_id, email])
      : get('SELECT * FROM utilizadores WHERE escola_id = ? AND codigo_acesso = ?', [escola_id, codigo_acesso]);

    if (!utilizador) return res.status(404).json({ erro: 'Utilizador não encontrado' });
    delete utilizador.password_hash;
    res.json(utilizador);
  });

  // POST /api/utilizadores — criar conta (aluno, encarregado, professor, staff)
  router.post('/api/utilizadores', (req, res) => {
    const { escola_id, tipo, nome, email, telefone, codigo_acesso, departamento, cargo } = req.body;
    if (!tipo || !nome) return res.status(400).json({ erro: 'tipo e nome são obrigatórios' });

    const result = run(
      `INSERT INTO utilizadores (escola_id, tipo, nome, email, telefone, codigo_acesso, departamento, cargo)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [escola_id || null, tipo, nome, email || null, telefone || null, codigo_acesso || null, departamento || null, cargo || null]
    );
    res.json(get('SELECT * FROM utilizadores WHERE id = ?', [result.id]), 201);
  });

  // GET /api/utilizadores?escola_id=&tipo=
  router.get('/api/utilizadores', (req, res) => {
    const { escola_id, tipo } = req.query;
    let sql = 'SELECT * FROM utilizadores WHERE 1=1';
    const params = [];
    if (escola_id) { sql += ' AND escola_id = ?'; params.push(escola_id); }
    if (tipo) { sql += ' AND tipo = ?'; params.push(tipo); }
    res.json(all(sql, params));
  });

  // GET /api/alunos/:id — ficha completa do aluno (o que o "Portal do Aluno" mostra)
  router.get('/api/alunos/:id', (req, res) => {
    const id = req.params.id;
    const aluno = get("SELECT * FROM utilizadores WHERE id = ? AND tipo = 'aluno'", [id]);
    if (!aluno) return res.status(404).json({ erro: 'Aluno não encontrado' });

    aluno.ficha = get('SELECT * FROM alunos_ficha WHERE utilizador_id = ?', [id]);
    aluno.notas = all(
      `SELECT n.*, a.nome AS avaliacao_nome, d.nome AS disciplina_nome
       FROM notas n
       JOIN avaliacoes a ON a.id = n.avaliacao_id
       LEFT JOIN disciplinas d ON d.id = a.disciplina_id
       WHERE n.aluno_id = ?`,
      [id]
    );
    aluno.propinas = all('SELECT * FROM propinas_mensais WHERE aluno_id = ? ORDER BY ano, mes', [id]);
    aluno.documentos = all('SELECT * FROM documentos_aluno WHERE aluno_id = ?', [id]);
    aluno.pedidosDocumentos = all('SELECT * FROM pedidos_documentos WHERE aluno_id = ? ORDER BY criado_em DESC', [id]);
    aluno.confirmacoes = all('SELECT * FROM confirmacoes_pendentes WHERE utilizador_id = ?', [id]);
    res.json(aluno);
  });
};
