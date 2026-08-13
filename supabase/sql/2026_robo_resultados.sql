-- Robo de teste: tabela onde cada rodada registra o resultado de cada
-- checagem (sucesso/erro/duracao). "rodada_id" agrupa todas as
-- checagens de uma mesma execucao do robo, pra dar pra ver "a rodada
-- das 08h teve 2 erros" de uma vez.
--
-- Quem ESCREVE aqui e o proprio robo, usando a chave de servico
-- (bypassa RLS -- por isso nao existe policy de insert pra ninguem).
-- Quem LE e so admin/admin financeiro, pela tela de resultados.

create table if not exists public.testes_automatizados_execucoes (
  id uuid primary key default gen_random_uuid(),
  rodada_id uuid not null,
  nome_teste text not null,
  sucesso boolean not null,
  erro text,
  duracao_ms integer not null,
  criado_em timestamptz not null default now()
);

create index if not exists idx_testes_automatizados_rodada
  on public.testes_automatizados_execucoes (rodada_id, criado_em);

alter table public.testes_automatizados_execucoes enable row level security;

create policy "testes_automatizados_execucoes_select" on public.testes_automatizados_execucoes
  for select using (is_admin() or is_admin_financeiro());
