// db.js
// Liga-se ao ficheiro SQLite do projeto usando o módulo nativo `node:sqlite`
// do Node.js (disponível a partir do Node 22, sem instalar nada via npm).
// Se a base de dados ainda não existir, cria-a a partir do schema.sql.

const { DatabaseSync } = require('node:sqlite');
const fs = require('node:fs');
const path = require('node:path');

// Em produção (ex.: Render com disco persistente) definimos DB_PATH para
// apontar para esse disco, para a base de dados não se perder a cada deploy.
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'portal.db');
const SCHEMA_PATH = path.join(__dirname, 'schema.sql');

const dbExisted = fs.existsSync(DB_PATH);
const db = new DatabaseSync(DB_PATH);
db.exec('PRAGMA foreign_keys = ON;');

if (!dbExisted) {
  console.log('A criar a base de dados a partir de schema.sql ...');
  const schema = fs.readFileSync(SCHEMA_PATH, 'utf8');
  db.exec(schema);
  console.log('Base de dados criada em', DB_PATH);
}

// Pequenos helpers para não repetir prepare/run/all em cada rota.
function all(sql, params = []) {
  return db.prepare(sql).all(...params);
}
function get(sql, params = []) {
  return db.prepare(sql).get(...params);
}
function run(sql, params = []) {
  const info = db.prepare(sql).run(...params);
  return { id: Number(info.lastInsertRowid), changes: info.changes };
}

module.exports = { db, all, get, run };
