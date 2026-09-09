# Portal do Aluno — pronto para subir para a nuvem

## O que mudou

O ficheiro `frontend/portal-do-aluno.html` já está ligado à API:

- **Login** (aluno/encarregado e staff) carrega a escola e o mural via API.
- **Mural** (`publish`, `publicar-pauta`) grava publicações na API.
- **Curtir publicação** grava na API.
- **Lançar nota** envia para `/api/notas`.
- **Pagar propina** marca a propina como paga na API (além do WhatsApp).
- **Matrícula** grava o pedido na API (além do WhatsApp).
- **Chat** grava mensagens na API.
- **Chamada/presença** grava em `/api/presencas`.

Se a API estiver offline ou o URL estiver errado, a app **não parte** —
continua a funcionar só com os dados de exemplo em memória, como já
funcionava antes. Isto é propositado: mantém o protótipo utilizável mesmo
sem backend.

**Nota importante sobre os IDs**: o protótipo original trabalha com nomes
(ex. "Turma A", "Ana Paula") e a base de dados trabalha com IDs numéricos.
Já liguei os pontos mais importantes (login, mural, propinas, matrícula,
chat, curtidas). Notas e presenças só serão gravadas na base de dados
quando existirem os atributos `data-turma-id` / `data-aluno-id` /
`data-disciplina-id` nos formulários — hoje o protótipo ainda não gera
esses IDs porque os dados de demonstração são só texto. Para ligar isso
por completo, o próximo passo é: ao carregar uma escola pela API, também
carregar as turmas/alunos reais e passar os IDs certos para esses
formulários. Fica documentado aqui para continuares depois — o padrão
a seguir é sempre o mesmo (`apiPost` já está pronto, só falta o ID certo).

## Passo 1 — Backend (API) no Render

1. Cria um repositório Git só com a pasta `portal-do-aluno-api/` (ou usa
   um monorepo, tanto faz).
2. Em [render.com](https://render.com), **New → Web Service**, liga o
   repositório.
3. Configurações:
   - **Runtime**: Node
   - **Build command**: (vazio, não há dependências)
   - **Start command**: `node server.js`
   - **Node version**: 22.5 ou superior (variável de ambiente
     `NODE_VERSION=22.5.0` — já está no `render.yaml` incluído)
4. **Persistência dos dados**: o Render free tier tem disco *efémero* —
   cada deploy novo apaga o `portal.db`. Para um site de demonstração
   tudo bem. Para dados reais de uma escola, precisas de um plano pago
   com **disco persistente**:
   - Adiciona um disco montado em `/data`
   - Define a variável de ambiente `DB_PATH=/data/portal.db`
   - (o `render.yaml` incluído já faz isto — usa `render blueprint deploy`
     ou aponta o Render para este ficheiro)
5. No fim, terás um URL tipo `https://portal-do-aluno-api.onrender.com`.
   Testa em `https://.../health` — deve responder
   `{"status":"ok","servico":"portal-do-aluno-api"}`.

## Passo 2 — Ligar o frontend à API publicada

Abre `frontend/portal-do-aluno.html`, procura por `API_URL` perto do
início do `<script>`, e troca:

```js
var API_URL = "http://localhost:3001";
```

por:

```js
var API_URL = "https://portal-do-aluno-api.onrender.com";
```

## Passo 3 — Frontend no Netlify ou GitHub Pages

Continua exatamente como já fazias: arrasta o `portal-do-aluno.html`
para o Netlify, ou faz commit num repositório e ativa o GitHub Pages.
Não precisa de build — é um ficheiro único.

## Resumo do que falta para produção real

- [ ] Sincronizar turmas/alunos reais da API para dentro do protótipo
      (hoje entram por `apiCarregarEscola`, só a escola + mural).
- [ ] Passar `data-turma-id` / `data-aluno-id` / `data-disciplina-id`
      nos formulários de notas e presenças.
- [ ] Trocar o disco efémero do Render por um plano com disco persistente
      antes de meter dados reais de alunos.
- [ ] Login por password real (hoje é por email/código de acesso, como
      já estava desenhado no `routes/utilizadores.js`).
