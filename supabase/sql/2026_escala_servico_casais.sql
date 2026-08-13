-- Fase 1 do plano "Escala Mensal -> Grade editavel": tabela pra lembrar
-- pareamentos de casal dos Diaconos (independente de dia/posicao especifica).
--
-- Este arquivo NAO roda automaticamente -- nao ha pipeline de migration
-- neste repo. Cole o conteudo abaixo no Supabase Dashboard -> SQL Editor
-- e rode manualmente.

create table if not exists public.escala_servico_casais (
  id uuid primary key default gen_random_uuid(),
  ministerio text not null,
  profile_id_a uuid not null references public.profiles(id) on delete cascade,
  profile_id_b uuid not null references public.profiles(id) on delete cascade,
  criado_por uuid references public.profiles(id),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint escala_servico_casais_ordem check (profile_id_a < profile_id_b),
  constraint escala_servico_casais_par_unico unique (ministerio, profile_id_a, profile_id_b)
);

alter table public.escala_servico_casais enable row level security;

-- Reaproveita as MESMAS funcoes que ja protegem escala_servico_posicoes
-- em producao (confirmado via pg_policies): is_admin() e
-- is_lider_ministerio(ministerio text). Nao duplica a logica na mao.
drop policy if exists "escala_servico_casais_select" on public.escala_servico_casais;
drop policy if exists "escala_servico_casais_insert" on public.escala_servico_casais;
drop policy if exists "escala_servico_casais_update" on public.escala_servico_casais;
drop policy if exists "escala_servico_casais_delete" on public.escala_servico_casais;

create policy "escala_servico_casais_select" on public.escala_servico_casais
  for select using (
    is_admin()
    or is_lider_ministerio(ministerio)
    or exists (
      select 1 from public.profile_ministerios pm
      where pm.profile_id = auth.uid() and pm.ministerio = escala_servico_casais.ministerio
    )
  );

create policy "escala_servico_casais_insert" on public.escala_servico_casais
  for insert with check (is_lider_ministerio(ministerio));

create policy "escala_servico_casais_update" on public.escala_servico_casais
  for update using (is_lider_ministerio(ministerio));

create policy "escala_servico_casais_delete" on public.escala_servico_casais
  for delete using (is_lider_ministerio(ministerio));
