const { all, get, run } = require('../db');

module.exports = function registerFinanceiroRoutes(router) {
  // GET /api/propinas?aluno_id=
  router.get('/api/propinas', (req, res) => {
    res.json(all('SELECT * FROM propinas_mensais WHERE aluno_id = ? ORDER BY ano, mes', [req.query.aluno_id]));
  });

  // POST /api/propinas/:id/pagar
  router.post('/api/propinas/:id/pagar', (req, res) => {
    run("UPDATE propinas_mensais SET status = 'ok', pago_em = datetime('now') WHERE id = ?", [req.params.id]);
    res.json(get('SELECT * FROM propinas_mensais WHERE id = ?', [req.params.id]));
  });

  // POST /api/matriculas — submissão do formulário de matrícula
  router.post('/api/matriculas', (req, res) => {
    const { escola_id, aluno_id, classe, curso_id, dados_extra } = req.body;
    if (!escola_id || !classe) return res.status(400).json({ erro: 'escola_id e classe são obrigatórios' });
    const result = run(
      `INSERT INTO matriculas (escola_id, aluno_id, classe, curso_id, dados_extra_json)
       VALUES (?, ?, ?, ?, ?)`,
      [escola_id, aluno_id || null, classe, curso_id || null, JSON.stringify(dados_extra || {})]
    );
    res.json(get('SELECT * FROM matriculas WHERE id = ?', [result.id]), 201);
  });

  // GET /api/matriculas?escola_id=
  router.get('/api/matriculas', (req, res) => {
    res.json(all('SELECT * FROM matriculas WHERE escola_id = ? ORDER BY criado_em DESC', [req.query.escola_id]));
  });

  // GET /api/pedidos-documentos?aluno_id=
  router.get('/api/pedidos-documentos', (req, res) => {
    res.json(all('SELECT * FROM pedidos_documentos WHERE aluno_id = ? ORDER BY criado_em DESC', [req.query.aluno_id]));
  });

  // POST /api/pedidos-documentos — aluno pede um documento
  router.post('/api/pedidos-documentos', (req, res) => {
    const { aluno_id, tipo } = req.body;
    if (!aluno_id || !tipo) return res.status(400).json({ erro: 'aluno_id e tipo são obrigatórios' });
    const result = run(
      "INSERT INTO pedidos_documentos (aluno_id, tipo, estado) VALUES (?, ?, 'Solicitado')",
      [aluno_id, tipo]
    );
    res.json(get('SELECT * FROM pedidos_documentos WHERE id = ?', [result.id]), 201);
  });

  // PUT /api/pedidos-documentos/:id — secretaria atualiza o estado do pedido
  router.put('/api/pedidos-documentos/:id', (req, res) => {
    const { estado } = req.body;
    run('UPDATE pedidos_documentos SET estado = ? WHERE id = ?', [estado, req.params.id]);
    res.json(get('SELECT * FROM pedidos_documentos WHERE id = ?', [req.params.id]));
  });

  // GET /api/presencas?turma_id=&data=
  router.get('/api/presencas', (req, res) => {
    const { turma_id, data } = req.query;
    let sql = `SELECT p.*, u.nome AS aluno FROM presencas p
               JOIN utilizadores u ON u.id = p.aluno_id WHERE p.turma_id = ?`;
    const params = [turma_id];
    if (data) { sql += ' AND p.data = ?'; params.push(data); }
    res.json(all(sql, params));
  });

  // POST /api/presencas — grava a chamada do dia
  // body: { turma_id, data, registos: [{ aluno_id, status }] }
  router.post('/api/presencas', (req, res) => {
    const { turma_id, data, registos } = req.body;
    if (!turma_id || !Array.isArray(registos)) {
      return res.status(400).json({ erro: 'turma_id e registos[] são obrigatórios' });
    }
    const dia = data || new Date().toISOString().slice(0, 10);
    registos.forEach((r) => {
      run(
        `INSERT INTO presencas (turma_id, aluno_id, data, status) VALUES (?, ?, ?, ?)
         ON CONFLICT(turma_id, aluno_id, data) DO UPDATE SET status = excluded.status`,
        [turma_id, r.aluno_id, dia, r.status]
      );
    });
    const presentes = registos.filter((r) => r.status === 'presente').length;
    const faltas = registos.filter((r) => r.status === 'falta').length;
    const atrasos = registos.filter((r) => r.status === 'atraso').length;
    run(
      `INSERT INTO presencas_resumo (turma_id, data, presentes, faltas, atrasos) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(turma_id, data) DO UPDATE SET presentes = excluded.presentes, faltas = excluded.faltas, atrasos = excluded.atrasos`,
      [turma_id, dia, presentes, faltas, atrasos]
    );
    res.json({ ok: true }, 201);
  });
};
