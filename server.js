// server.js
// Servidor da API do Portal do Aluno.
// Sem dependências externas: usa apenas `node:http` e `node:sqlite`
// (o SQLite embutido no Node — precisa do Node 22 ou superior).
//
// Para arrancar: node server.js
// A API fica disponível em http://localhost:3001

const http = require('node:http');
const path = require('node:path');
const fs = require('node:fs');
const { Router } = require('./router');

require('./db'); // garante que a base de dados é criada/aberta ao arrancar

const router = new Router();

require('./routes/escolas')(router);
require('./routes/utilizadores')(router);
require('./routes/academico')(router);
require('./routes/financeiro')(router);
require('./routes/social')(router);

const baseHandler = router.handler();

const PORT = process.env.PORT || 3001;

const server = http.createServer((req, res) => {
  // CORS simples — permite que o ficheiro HTML (aberto em file:// ou noutra
  // porta) chame esta API a partir do browser.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.url === '/' || req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', servico: 'portal-do-aluno-api' }));
    return;
  }

  baseHandler(req, res);
});

server.listen(PORT, () => {
  console.log(`Portal do Aluno API a correr em http://localhost:${PORT}`);
});
