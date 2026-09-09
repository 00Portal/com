// router.js
// Um router minúsculo, ao estilo Express (router.get/post/put + req.params/
// req.query/req.body + res.json/res.status), mas escrito só com módulos
// nativos do Node (`http`, `url`). Não precisa de `npm install`.

const { URL } = require('node:url');

function pathToRegex(path) {
  const paramNames = [];
  const pattern = path
    .replace(/\/:([^/]+)/g, (_, name) => {
      paramNames.push(name);
      return '/([^/]+)';
    });
  return { regex: new RegExp(`^${pattern}$`), paramNames };
}

class Router {
  constructor() {
    this.routes = []; // { method, regex, paramNames, handler }
  }

  _add(method, path, handler) {
    const { regex, paramNames } = pathToRegex(path);
    this.routes.push({ method, regex, paramNames, handler });
  }

  get(path, handler) { this._add('GET', path, handler); }
  post(path, handler) { this._add('POST', path, handler); }
  put(path, handler) { this._add('PUT', path, handler); }
  delete(path, handler) { this._add('DELETE', path, handler); }

  // Devolve um handler pronto a passar para http.createServer(...)
  handler() {
    return (req, res) => {
      const url = new URL(req.url, `http://${req.headers.host}`);
      const pathname = decodeURIComponent(url.pathname);

      res.json = (data, status = 200) => {
        res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify(data));
      };
      res.status = (code) => ({ json: (data) => res.json(data, code) });

      req.query = Object.fromEntries(url.searchParams.entries());

      const match = this.routes.find(
        (r) => r.method === req.method && r.regex.test(pathname)
      );

      if (!match) {
        res.json({ erro: 'Rota não encontrada', path: pathname }, 404);
        return;
      }

      const values = match.regex.exec(pathname).slice(1);
      req.params = Object.fromEntries(match.paramNames.map((n, i) => [n, values[i]]));

      if (req.method === 'GET' || req.method === 'DELETE') {
        try {
          match.handler(req, res);
        } catch (err) {
          console.error(err);
          res.json({ erro: 'Erro interno', detalhe: err.message }, 500);
        }
        return;
      }

      // POST/PUT: ler o corpo JSON antes de chamar o handler
      let body = '';
      req.on('data', (chunk) => { body += chunk; });
      req.on('end', () => {
        try {
          req.body = body ? JSON.parse(body) : {};
          match.handler(req, res);
        } catch (err) {
          console.error(err);
          res.json({ erro: 'Corpo inválido ou erro interno', detalhe: err.message }, 400);
        }
      });
    };
  }
}

module.exports = { Router };
