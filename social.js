const { all, get, run } = require('../db');

module.exports = function registerSocialRoutes(router) {
  // GET /api/publicacoes?escola_id= — feed/mural da escola
  router.get('/api/publicacoes', (req, res) => {
    res.json(
      all(
        `SELECT p.*, u.nome AS autor_nome
         FROM publicacoes p LEFT JOIN utilizadores u ON u.id = p.autor_id
         WHERE p.escola_id = ? ORDER BY p.criado_em DESC`,
        [req.query.escola_id]
      )
    );
  });

  // POST /api/publicacoes — publicar aviso/evento/etc. no mural
  router.post('/api/publicacoes', (req, res) => {
    const { escola_id, autor_id, tag, corpo } = req.body;
    if (!escola_id || !corpo) return res.status(400).json({ erro: 'escola_id e corpo são obrigatórios' });
    const result = run(
      'INSERT INTO publicacoes (escola_id, autor_id, tag, corpo) VALUES (?, ?, ?, ?)',
      [escola_id, autor_id || null, tag || null, corpo]
    );
    res.json(get('SELECT * FROM publicacoes WHERE id = ?', [result.id]), 201);
  });

  // POST /api/publicacoes/:id/curtir
  router.post('/api/publicacoes/:id/curtir', (req, res) => {
    const { utilizador_id } = req.body;
    run(
      'INSERT OR IGNORE INTO curtidas (publicacao_id, utilizador_id) VALUES (?, ?)',
      [req.params.id, utilizador_id]
    );
    const total = get('SELECT count(*) AS n FROM curtidas WHERE publicacao_id = ?', [req.params.id]);
    res.json({ total: total.n });
  });

  // GET /api/recursos?escola_id=&tipo=livro|video
  router.get('/api/recursos', (req, res) => {
    const { escola_id, tipo } = req.query;
    let sql = 'SELECT * FROM recursos WHERE (escola_id = ? OR origem = "portal")';
    const params = [escola_id || null];
    if (tipo) { sql += ' AND tipo = ?'; params.push(tipo); }
    res.json(all(sql, params));
  });

  // GET /api/conversas/:id/mensagens
  router.get('/api/conversas/:id/mensagens', (req, res) => {
    res.json(
      all(
        `SELECT m.*, u.nome AS autor_nome
         FROM mensagens_chat m LEFT JOIN utilizadores u ON u.id = m.autor_id
         WHERE m.conversa_id = ? ORDER BY m.enviado_em ASC`,
        [req.params.id]
      )
    );
  });

  // POST /api/conversas/:id/mensagens
  router.post('/api/conversas/:id/mensagens', (req, res) => {
    const { autor_id, corpo } = req.body;
    if (!corpo) return res.status(400).json({ erro: 'corpo é obrigatório' });
    const result = run(
      'INSERT INTO mensagens_chat (conversa_id, autor_id, corpo) VALUES (?, ?, ?)',
      [req.params.id, autor_id || null, corpo]
    );
    res.json(get('SELECT * FROM mensagens_chat WHERE id = ?', [result.id]), 201);
  });
};
