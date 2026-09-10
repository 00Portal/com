const { all, get, run } = require('../db');

module.exports = function registerEscolasRoutes(router) {
  // GET /api/escolas — lista todas as escolas (para o ecrã de login/pesquisa)
  router.get('/api/escolas', (req, res) => {
    const rows = all('SELECT * FROM escolas ORDER BY nome');
    res.json(rows);
  });

  // GET /api/escolas/:slug — detalhe de uma escola + cursos/classes/serviços
  router.get('/api/escolas/:slug', (req, res) => {
    const escola = get('SELECT * FROM escolas WHERE slug = ?', [req.params.slug]);
    if (!escola) return res.status(404).json({ erro: 'Escola não encontrada' });

    escola.cursos = all('SELECT * FROM cursos WHERE escola_id = ?', [escola.id]);
    escola.classes = all('SELECT * FROM classes_oferecidas WHERE escola_id = ?', [escola.id]);
    escola.servicos = all('SELECT nome FROM servicos_escola WHERE escola_id = ?', [escola.id]).map(r => r.nome);
    escola.documentosTipos = all('SELECT nome FROM tipos_documento WHERE escola_id = ?', [escola.id]).map(r => r.nome);
    res.json(escola);
  });

  // GET /api/escolas/:slug/turmas
  router.get('/api/escolas/:slug/turmas', (req, res) => {
    const escola = get('SELECT id FROM escolas WHERE slug = ?', [req.params.slug]);
    if (!escola) return res.status(404).json({ erro: 'Escola não encontrada' });
    res.json(all('SELECT * FROM turmas WHERE escola_id = ? ORDER BY nome', [escola.id]));
  });

  // GET /api/escolas/:slug/disciplinas
  router.get('/api/escolas/:slug/disciplinas', (req, res) => {
    const escola = get('SELECT id FROM escolas WHERE slug = ?', [req.params.slug]);
    if (!escola) return res.status(404).json({ erro: 'Escola não encontrada' });
    res.json(all('SELECT * FROM disciplinas WHERE escola_id = ? ORDER BY nome', [escola.id]));
  });

  // GET /api/escolas/:slug/calendario
  router.get('/api/escolas/:slug/calendario', (req, res) => {
    const escola = get('SELECT id FROM escolas WHERE slug = ?', [req.params.slug]);
    if (!escola) return res.status(404).json({ erro: 'Escola não encontrada' });
    res.json(all('SELECT * FROM eventos_calendario WHERE escola_id = ?', [escola.id]));
  });
};
