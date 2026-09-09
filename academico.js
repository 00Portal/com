const { all, get, run } = require('../db');

// Regra do protótipo original: a escala (10 ou 20) depende da classe da
// turma. Mantemos essa lógica aqui, no servidor, para que fique consistente
// não importa quem lança a nota.
function escalaDaClasse(classe) {
  const numero = parseInt(String(classe).match(/\d+/)?.[0] || '0', 10);
  return numero >= 7 ? 20 : 10;
}

module.exports = function registerAcademicoRoutes(router) {
  // GET /api/turmas/:id/notas — pauta de uma turma (todas as avaliações)
  router.get('/api/turmas/:id/notas', (req, res) => {
    const rows = all(
      `SELECT n.id, n.nota, n.escala, n.situacao,
              av.nome AS avaliacao, d.nome AS disciplina,
              u.id AS aluno_id, u.nome AS aluno
       FROM notas n
       JOIN avaliacoes av ON av.id = n.avaliacao_id
       LEFT JOIN disciplinas d ON d.id = av.disciplina_id
       JOIN utilizadores u ON u.id = n.aluno_id
       WHERE av.turma_id = ?
       ORDER BY av.nome, u.nome`,
      [req.params.id]
    );
    res.json(rows);
  });

  // POST /api/notas — professor lança uma nota
  // body: { turma_id, disciplina_id, aluno_id, avaliacao, nota }
  router.post('/api/notas', (req, res) => {
    const { turma_id, disciplina_id, aluno_id, avaliacao, nota } = req.body;
    if (!turma_id || !aluno_id || !avaliacao || nota === undefined) {
      return res.status(400).json({ erro: 'turma_id, aluno_id, avaliacao e nota são obrigatórios' });
    }
    const turma = get('SELECT * FROM turmas WHERE id = ?', [turma_id]);
    if (!turma) return res.status(404).json({ erro: 'Turma não encontrada' });
    const escala = escalaDaClasse(turma.classe);

    let av = get(
      'SELECT * FROM avaliacoes WHERE turma_id = ? AND nome = ? AND disciplina_id IS ?',
      [turma_id, avaliacao, disciplina_id || null]
    );
    if (!av) {
      const r = run(
        'INSERT INTO avaliacoes (turma_id, disciplina_id, nome) VALUES (?, ?, ?)',
        [turma_id, disciplina_id || null, avaliacao]
      );
      av = { id: r.id };
    }

    const situacao = nota >= (escala === 20 ? 10 : 5) ? 'Aprovado' : 'Em recuperação';

    run(
      `INSERT INTO notas (avaliacao_id, aluno_id, nota, escala, situacao)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(avaliacao_id, aluno_id) DO UPDATE SET nota = excluded.nota, situacao = excluded.situacao`,
      [av.id, aluno_id, nota, escala, situacao]
    );

    res.json({ ok: true, escala, situacao }, 201);
  });

  // GET /api/pautas?turma_id=
  router.get('/api/pautas', (req, res) => {
    const { turma_id } = req.query;
    let sql = 'SELECT * FROM pautas WHERE 1=1';
    const params = [];
    if (turma_id) { sql += ' AND turma_id = ?'; params.push(turma_id); }
    const pautas = all(sql, params);
    pautas.forEach((p) => {
      p.resultados = all(
        `SELECT pr.situacao, u.nome AS aluno
         FROM pauta_resultados pr JOIN utilizadores u ON u.id = pr.aluno_id
         WHERE pr.pauta_id = ?`,
        [p.id]
      );
    });
    res.json(pautas);
  });

  // POST /api/pautas — publicar pauta (turma_id, ano, resultados: [{aluno_id, situacao}])
  router.post('/api/pautas', (req, res) => {
    const { turma_id, ano, resultados } = req.body;
    if (!turma_id || !ano || !Array.isArray(resultados)) {
      return res.status(400).json({ erro: 'turma_id, ano e resultados[] são obrigatórios' });
    }
    const pauta = run('INSERT INTO pautas (turma_id, ano) VALUES (?, ?)', [turma_id, ano]);
    resultados.forEach((r) => {
      run('INSERT INTO pauta_resultados (pauta_id, aluno_id, situacao) VALUES (?, ?, ?)', [pauta.id, r.aluno_id, r.situacao]);
    });
    res.json({ ok: true, pauta_id: pauta.id }, 201);
  });

  // GET /api/horarios?turma_id=
  router.get('/api/horarios', (req, res) => {
    const { turma_id } = req.query;
    let sql = `SELECT h.*, d.nome AS disciplina FROM horario_aulas h
               LEFT JOIN disciplinas d ON d.id = h.disciplina_id WHERE 1=1`;
    const params = [];
    if (turma_id) { sql += ' AND h.turma_id = ?'; params.push(turma_id); }
    res.json(all(sql, params));
  });
};
