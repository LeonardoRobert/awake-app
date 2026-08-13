# Shallom App (awake_app) — Contexto do projeto

Este arquivo é lido automaticamente pelo Claude Code toda vez que o projeto é
aberto. Ele existe pra você (Claude Code) entender o projeto inteiro ANTES de
mexer em qualquer coisa — sem precisar que o Leo (dono do projeto) explique
tudo de novo a cada conversa.

## 🚨 Regra mais importante de todas

**Faça SOMENTE o que foi pedido, e nada além disso.**

- Se o Leo pedir uma correção pequena, mude só o necessário pra resolver
  aquilo — não aproveite pra "melhorar", refatorar, reorganizar imports,
  trocar nomes de variável, ou mexer em qualquer outro trecho do arquivo
  que não tenha relação direta com o pedido.
- Nunca reescreva um arquivo inteiro quando um `str_replace`/edit cirúrgico
  resolve.
- Se perceber algo que parece um bug ou uma melhoria óbvia **fora** do que
  foi pedido, **avise o Leo e pergunte antes** — não corrija por conta
  própria no mesmo pedido.
- Antes de editar um arquivo, **leia o conteúdo atual dele primeiro** (não
  confie em memória de conversas passadas — o projeto já teve vários
  incidentes de arquivos desatualizados causando builds quebrados).
- Depois de editar, confirme que chaves/parênteses fecham certo antes de
  entregar.

## Primeira tarefa: faça uma varredura

Antes de qualquer alteração, explore a estrutura do projeto (`lib/`,
`docs/`, `.github/workflows/`, `supabase` se houver pasta de migrations) pra
se familiarizar de verdade com o código atual — este documento dá o
panorama, mas o código-fonte é sempre a fonte da verdade.

---

## O que é o projeto

App de gestão de igreja em Flutter + Supabase, pra Comunidade Batista
Shallom em Meriti (RJ). Serve tanto como ferramenta de produção pra igreja
real quanto como protótipo pra um modelo de negócio futuro (vender apps
parecidos pra outras igrejas da Baixada Fluminense).

**Identidade dupla:** o mesmo app se adapta visualmente conforme o perfil
da pessoa — **Awake** (ministério de jovens: navy + amarelo) e **Shallom**
(demais ministérios — Homens, Mulheres: navy + dourado + creme). Isso é
decidido em tempo real, não são apps separados.

## Stack técnica

- **Frontend:** Flutter + Riverpod (state management) + go_router (rotas)
- **Backend:** Supabase (Postgres + RLS + Edge Functions + pg_cron)
- **Notificações push:** OneSignal (via REST API, chamada de dentro de
  Edge Functions — nunca direto do app)
- **Pagamentos:** Pix nativo (geração de BR Code/EMV com valor embutido,
  incluindo cálculo de CRC16 — ver `financeiro_screen.dart`) + PagBank
  (links de pagamento fixos pro cartão)
- **Conteúdo:** YouTube Data API v3 (playlist de uploads, não busca por
  palavra-chave — a busca dá resultados fora de ordem)
- **CI/CD:** GitHub Actions (2 workflows principais — ver abaixo)
- **Hospedagem:** GitHub Pages (`docs/` na branch `main`)

## Credenciais (já configuradas como Secrets/Env — não são segredo pra você
ler, mas nunca devem aparecer hard-coded em lugar novo que não seja um
dart-define ou Supabase Secret)

- Supabase URL: `https://eetethnvupitlquhdjkx.supabase.co`
- OneSignal App ID: `72736b79-2f73-4ff3-8171-f8bace6038ae`
- Chave Pix: `shallom.financeiro@gmail.com`
- Canal YouTube: `UCJjMlNpqp4JmorV6bCLprXg` (playlist de uploads:
  `UUJjMlNpqp4JmorV6bCLprXg`)

## Estrutura de pastas

```
lib/
  core/
    router.dart              # todas as rotas (GoRouter)
    theme/app_theme.dart      # AwakeColors + ShallomColors, tema claro/escuro
  models/                     # EventModel, ProfileModel, ContribuicaoModel,
                               # ShiftModel, SignupModel, VisitanteModel...
  providers/                  # Riverpod providers (auth, event, contribuicao, shift)
  services/                   # Chamadas ao Supabase (um service por domínio)
  screens/                    # Organizado por feature: auth/, calendar/,
                               # financeiro/, home/, messages/, metas/,
                               # pages/, profile/, training/, volunteering/
  widgets/                    # AwakeAppBar, EventoSemanaCard,
                               # LinkFormularioVisitante, QuemEstaEscalado,
                               # escala_fluxo.dart (fluxo de criar escala)

docs/                         # Publicado via GitHub Pages
  index.html                  # Página de download (Android/iPhone)
  site.html                   # Site institucional público (Quem Somos,
                               # Vídeos, Agenda dinâmica, Contribua)
  gestao.html                 # Painel desktop separado (login próprio via
                               # Supabase Auth) — Calendário pro Admin,
                               # Financeiro pro Admin Financeiro
  app/                        # Build do Flutter Web — GERADO AUTOMATICAMENTE,
                               # NUNCA edite à mão, é sobrescrito a cada deploy

.github/workflows/
  build-release.yml           # Gera o APK, publica em GitHub Releases
  deploy-web.yml               # Builda Flutter Web, publica em docs/app
  keep-supabase-awake.yml      # Ping periódico pro Supabase não hibernar
```

## Convenções do código

- **Idioma:** tudo em português (nomes de variável, classe, comentários,
  strings de UI). Comentários explicativos usam português sem acento em
  alguns arquivos mais antigos (inconsistente, não se preocupe em
  normalizar isso).
- **Nomenclatura de banco:** snake_case nas colunas/tabelas Postgres,
  camelCase nos models Dart, com `fromMap`/`toInsertMap` fazendo a ponte.
- **RLS é a fonte de verdade de permissão** — várias telas fazem checagem
  de UI (esconder botão) mas a proteção real está nas policies do banco.
- **Papéis de usuário:** `profiles.papel` pode ser `membro`, `admin`, ou
  `admin_financeiro`. Liderança de ministério é modelada separadamente em
  `profile_ministerios` (campo `eh_lider`).

## Módulos principais (visão rápida)

- **Calendário:** eventos com `escopo` (igreja/homens/mulheres/awake/
  casais/liderança/ministérios de serviço/etc) e `tipo` (só relevante
  dentro de igreja/awake). Suporta recorrência semanal com filtro de
  "quais semanas do mês" (`semanas_do_mes`). Eventos podem ser marcados
  como `ingressado` (retiro/conferência paga) com `valor_total`,
  `parcelas_sugeridas`, `metodos_pagamento`.
- **Escala de Serviço** (Diáconos, Louvor, Dança, Mídia, Multimídia,
  Coral): `escalas_servico` + `escala_servico_posicoes`. Diáconos usa
  posições em casal (dois `profile_id` por posição).
- **Escala Awake** (voluntariado com vagas, mais antigo): `areas_servico`
  + `escalas` + `inscricoes`. Tem check-in por QR Code.
- **Financeiro:** `contribuicoes` (dízimo/oferta/cartão), com vínculo
  opcional a um evento ingressado via `evento_id`. Pix gerado
  dinamicamente com valor embutido (EMV/BR Code + CRC16) tanto no app
  quanto no `site.html`.
- **Cuidado pastoral:** `pedidos_oracao`, `testemunhos`,
  `visitantes_primeira_vez` (formulário preenchido pelo voluntário
  escalado em "Recepção/Primeira Vez" sobre quem visitou).
- **Notificações:** Edge Function `send-notification` (chamada por
  triggers do Postgres) + `pg_cron` rodando `processar_lembretes()` a
  cada 15 min pra lembretes de 24h/3h antes de eventos e escalas.
- **Metas mensais:** `meta_mensal_model.dart` + `metas_provider.dart` +
  `metas_service.dart`, telas em `screens/metas/`. Metas fixas por
  ministério (EBD, GC, comunhão, escala — ver `MetasConfig`), com
  dashboard de acompanhamento pro líder (`leader_dashboard_view.dart`) e
  visão individual pro membro (`member_metas_view.dart`).
- **Filhos:** `filho_model.dart` + `filho_provider.dart` +
  `filho_service.dart`. Cadastro de filho vinculado ao perfil do
  responsável (sem conta/login próprio) — usado só pra liberar
  visibilidade de eventos de Crianças e de Embaixadores/Mensageiras
  conforme a idade.
- **Questionário de novo servo:** `questionario_model.dart` +
  `link_questionario_novo_servo.dart`. Formulário respondido por quem
  está entrando pra servir num ministério; aparece pro admin/líder em
  `admin_mensagens_screen.dart` junto com pedidos de oração e
  testemunhos.

## Armadilhas já conhecidas (não repita esses erros)

- **`file_picker` precisa ficar em `^10.3.10`** — a versão 11.x tem um bug
  de empacotamento conhecido (falta o plugin Kotlin no `build.gradle`
  deles) que quebra o build Android. Não faça upgrade sem testar.
- **`compileSdk` precisa ser `36`** em `android/app/build.gradle.kts`
  (exigência transitiva de outras dependências).
- **`docs/.nojekyll` precisa existir e ficar sempre vazio (0 bytes)** —
  sem ele, o GitHub Pages usa Jekyll pra processar os arquivos e pode
  remover coisas silenciosamente. Já aconteceu de esse arquivo acabar
  com conteúdo HTML dentro por acidente de commit — se isso se repetir,
  é só esvaziar, nunca precisa ter texto.
- **"categoria" no `site.html`/`gestao.html` não é campo de banco** — é
  um rótulo calculado em tempo real no JavaScript, que traduz o
  `escopo` do evento (igreja/homens/mulheres/awake) pra um texto mais
  amigável (Geral/Homens/Mulheres/Jovens). Não existe em
  `event_model.dart` nem precisa de migração — é derivado, só vive nos
  arquivos HTML/JS do site público.
- **Push em workflow disparado por tag cai em "detached HEAD"** — nunca
  use só `git push`, use `git push origin HEAD:main` dentro de workflows.
- **Nunca use `git add .` sem pensar** quando só uma mudança pequena foi
  feita — isso já causou conflitos feios com o commit automático que o
  `deploy-web.yml` faz em `docs/app/`. Prefira `git add <arquivo
  específico>` quando o Leo estiver mexendo só em algo pontual (ex:
  `docs/site.html`).
- **Datas/horários:** existe uma inconsistência conhecida em como
  `data_inicio` é gravado vs. como o app exibe — o site público
  (`site.html`) lê os dígitos de hora direto da string ISO, SEM aplicar
  conversão de fuso horário (`Intl.DateTimeFormat` com timezone causava
  horários errados). Se for mexer em exibição de data/hora em qualquer
  lugar novo, teste contra um horário conhecido antes de assumir que
  conversão de fuso é necessária.
- **`GeneratedPluginRegistrant.java`** pode ficar desatualizado depois de
  trocar versão de plugin — se der erro de classe não encontrada depois
  de mudar uma dependência nativa, tente `flutter clean` +  apagar esse
  arquivo manualmente antes de mais nada.

## Identidade visual

- **Navy:** `#0C192E` (fundo escuro, header, texto principal)
- **Awake:** amarelo `#FFD21F` + off-white `#F7F7F6`
- **Shallom:** dourado `#CBA135` + creme `#F7F2DD` + azul `#9BB0C7`
- **Fonte:** Plus Jakarta Sans (Google Fonts) — a fonte "oficial" da marca
  é Canva Sans, mas é proprietária e não pode ser embutida/redistribuída
  sem licença própria, então usamos essa como substituta aberta.
- **Wordmark:** "shallom" sempre em itálico + negrito, minúsculo.
- O site público (`site.html`) e o painel de gestão (`gestao.html`) já
  seguem essa identidade — qualquer tela nova deve manter consistência
  com eles.

## Cuidado com `supabase/schema.sql`

Esse arquivo **está desatualizado** e não reflete o banco de produção —
ele tem um aviso no topo explicando isso. O motivo: SQL novo ao longo do
projeto foi rodado direto no SQL Editor do Supabase e nunca voltou pro
repositório. Não confie nele pra saber quais tabelas/colunas existem de
verdade — o código Dart em `lib/services/` é a fonte de verdade mais
confiável hoje (cada service usa os nomes reais de tabela/coluna). Nunca
tente "recriar" ou "corrigir" esse arquivo do zero adivinhando o schema —
peça um dump real (Supabase Database → Backups, ou `pg_dump`) antes de
mexer nele.

## Coisas pendentes (o Leo sabe disso, não precisa perguntar de novo)

- Texto oficial de "Quem somos nós" — ainda com placeholder.
- Perguntas definitivas do formulário de visitante — pode mudar.
- Domínio próprio — ainda não comprado, tudo hoje roda em
  `leonardorobert.github.io/awake-app/`.
- Automação bancária (PagBank) — **pausada de propósito**. Existe uma
  Edge Function `pagbank-sync` e uma tabela `transacoes_bancarias` já
  construídas, mas desativadas/não usadas ativamente — não reative sem o
  Leo pedir explicitamente, e não assuma que "terminar" isso é uma boa
  ideia por conta própria (descobrimos que a API disponível não cobre
  bem o caso de uso, ver histórico se precisar entender o porquê).
