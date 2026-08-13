-- Suporte pra aba "Entradas" (dashboard mensal de arrecadacao) e pra
-- deduplicacao da importacao semanal de extrato.
--
-- Antes de mexer, conferido via pg_get_functiondef/pg_policies: nenhuma
-- policy de contribuicoes depende de profile_id ser sempre preenchido
-- -- contribuicoes_insert/update/delete so checam is_admin_financeiro();
-- contribuicoes_select cai pra is_admin_financeiro() quando profile_id
-- e nulo (nenhum membro comum enxerga essas linhas, so quem tem esse
-- cargo); contribuicoes_ocultar_teste tambem resolve certo (eh_conta_
-- teste(null) = false, linha fica visivel normal). Ou seja, nao precisa
-- mudar nenhuma policy -- so a estrutura da tabela.

-- Linha de extrato que nao casou com ninguem (ou foi marcada como
-- "ignorar" na revisao) agora tambem e salva aqui, com profile_id nulo
-- -- assim ela aparece no dashboard de Entradas e fica lembrada pra
-- nao ser reimportada/re-perguntada toda semana.
alter table public.contribuicoes
  alter column profile_id drop not null;

alter table public.contribuicoes
  add column if not exists motivo_sem_usuario text;

alter table public.contribuicoes
  drop constraint if exists contribuicoes_motivo_sem_usuario_check;
alter table public.contribuicoes
  add constraint contribuicoes_motivo_sem_usuario_check
  check (motivo_sem_usuario is null or motivo_sem_usuario in ('nao_cadastrado', 'sem_identificacao', 'ignorado'));

-- Trava de consistencia: linha sem dono TEM que explicar o motivo;
-- linha com dono nao deveria ter motivo (evita ficar inconsistente).
alter table public.contribuicoes
  drop constraint if exists contribuicoes_profile_ou_motivo_check;
alter table public.contribuicoes
  add constraint contribuicoes_profile_ou_motivo_check
  check (
    (profile_id is not null and motivo_sem_usuario is null)
    or (profile_id is null and motivo_sem_usuario is not null)
  );

-- De qual banco veio (nulo = lancamento manual, nao veio de extrato).
alter table public.contribuicoes
  add column if not exists banco_origem text;

alter table public.contribuicoes
  drop constraint if exists contribuicoes_banco_origem_check;
alter table public.contribuicoes
  add constraint contribuicoes_banco_origem_check
  check (banco_origem is null or banco_origem in ('pagbank', 'cora', 'stone'));

-- Chave de deduplicacao pra importacao semanal (banco + data + valor +
-- nome normalizado, e horario tambem quando o banco fornece -- hoje so
-- o Stone traz horario no extrato). Nula pra lancamento manual --
-- unique no Postgres nao considera NULL igual a NULL, entao varios
-- lancamentos manuais nunca colidem entre si por causa disso.
alter table public.contribuicoes
  add column if not exists chave_importacao text;

alter table public.contribuicoes
  drop constraint if exists contribuicoes_chave_importacao_key;
alter table public.contribuicoes
  add constraint contribuicoes_chave_importacao_key unique (chave_importacao);

-- Tipo ganha "oferta missionaria" e "movimento da paz" (fundo/campanha
-- proprios, escolhidos linha a linha igual dizimo/oferta -- nao e
-- derivado automaticamente de qual banco a entrada veio).
alter table public.contribuicoes
  drop constraint if exists contribuicoes_tipo_check;
alter table public.contribuicoes
  add constraint contribuicoes_tipo_check
  check (tipo is null or tipo in ('dizimo', 'oferta', 'oferta_missionaria', 'movimento_paz', 'outro'));
