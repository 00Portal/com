# Portal do Aluno — API

Servidor que liga o protótipo HTML a uma base de dados SQLite real.
**Não precisa de `npm install`** — usa só módulos nativos do Node
(`node:http` para o servidor, `node:sqlite` para a base de dados).

## Requisitos

- Node.js **22 ou superior** (`node --version`)

## Como arrancar

```bash
cd portal-do-aluno-api
node server.js
```

Vai aparecer:
```
Portal do Aluno API a correr em http://localhost:3001
```

Na primeira vez, cria automaticamente `portal.db` a partir de `schema.sql`
(com os dados de exemplo). Para recomeçar do zero, apaga `portal.db` e
arranca outra vez.

## Testar rapidamente

```bash
curl http://localhost:3001/api/escolas
curl http://localhost:3001/api/escolas/nova-esperanca
curl http://localhost:3001/api/alunos/3
```

## Rotas disponíveis

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/escolas` | Lista todas as escolas |
| GET | `/api/escolas/:slug` | Detalhe de uma escola (cursos, classes, serviços) |
| GET | `/api/escolas/:slug/turmas` | Turmas da escola |
| GET | `/api/escolas/:slug/disciplinas` | Disciplinas da escola |
| GET | `/api/escolas/:slug/calendario` | Eventos do calendário |
| POST | `/api/login` | Login por email ou código de acesso |
| POST | `/api/utilizadores` | Criar conta (aluno/encarregado/professor/staff) |
| GET | `/api/utilizadores?escola_id=&tipo=` | Listar utilizadores |
| GET | `/api/alunos/:id` | Ficha completa do aluno (notas, propinas, documentos...) |
| GET | `/api/turmas/:id/notas` | Pauta de uma turma |
| POST | `/api/notas` | Professor lança uma nota |
| GET/POST | `/api/pautas` | Consultar/publicar pautas |
| GET | `/api/horarios?turma_id=` | Horário de uma turma |
| GET | `/api/propinas?aluno_id=` | Mensalidades de um aluno |
| POST | `/api/propinas/:id/pagar` | Marcar mensalidade como paga |
| GET/POST | `/api/matriculas` | Consultar/submeter matrículas |
| GET/POST/PUT | `/api/pedidos-documentos` | Pedidos de documentos do aluno |
| GET/POST | `/api/presencas` | Consultar/gravar a chamada de uma turma |
| GET/POST | `/api/publicacoes?escola_id=` | Mural/feed da escola |
| POST | `/api/publicacoes/:id/curtir` | Curtir uma publicação |
| GET | `/api/recursos?escola_id=&tipo=` | Livros/vídeos |
| GET/POST | `/api/conversas/:id/mensagens` | Chat |

## Estrutura do projeto

```
portal-do-aluno-api/
├── server.js       # arranca o servidor HTTP
├── router.js        # mini-router (sem Express)
├── db.js            # ligação ao SQLite (node:sqlite)
├── schema.sql        # desenho das tabelas + dados de exemplo
├── portal.db         # criado automaticamente na 1ª execução
└── routes/
    ├── escolas.js
    ├── utilizadores.js
    ├── academico.js
    ├── financeiro.js
    └── social.js
```

## Próximo passo: ligar ao ficheiro HTML

Ver `exemplo-integracao.html` — mostra, com código real tirado do teu
ficheiro original, como trocar uma parte do `S` (estado em memória) por
chamadas `fetch()` a esta API, mantendo o resto da aplicação a funcionar
como já funciona.

Nota sobre CORS: se abrires o HTML diretamente com duplo-clique
(`file://...`), o browser pode bloquear os pedidos `fetch`. O mais seguro
é servir o HTML também por HTTP (por exemplo `npx serve` ou a extensão
"Live Server" do VS Code) enquanto o servidor da API está a correr.
