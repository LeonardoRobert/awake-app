-- "Ferramentas da Liderança" -- check-in em massa pros lideres dos
-- ministerios que NAO sao Awake (Homens, Mulheres, Danca, Intercessao,
-- Diaconos, Louvor, Midia, Multimidia, Coral, Teatro). E' 100% aditivo:
-- nao mexe em nada de Escala de Servico, Awake, ou no contador geral
-- (contagem_manual_eventos/presencas_eventos) que ja existem.
--
-- O lider escolhe um TIPO de ocasiao do proprio ministerio (Ensaio,
-- Reuniao, etc -- catalogo fixo por enquanto, ver
-- ocasioes_ministerio_catalogo) pra HOJE, cola uma lista de nomes, e o
-- sistema registra presenca so' de quem e' membro daquele ministerio
-- (profile_ministerios) -- isso alimenta metricas de participacao/
-- ausencia por pessoa.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create table if not exists public.ocasioes_ministerio_catalogo (
  id uuid primary key default gen_random_uuid(),
  ministerio text not null,
  nome text not null,
  ordem int not null default 99,
  unique (ministerio, nome)
);

alter table public.ocasioes_ministerio_catalogo enable row level security;
drop policy if exists "ocasioes_ministerio_catalogo_select" on public.ocasioes_ministerio_catalogo;
create policy "ocasioes_ministerio_catalogo_select" on public.ocasioes_ministerio_catalogo
  for select using (true);

-- Catalogo generico de partida (mesmo pra todos os ministerios nesta
-- rodada) -- da pra customizar por ministerio depois se precisar,
-- rodando um insert manual.
insert into public.ocasioes_ministerio_catalogo (ministerio, nome, ordem)
select ministerio, tipo, ordem
from (values
  ('homens', 'Ensaio', 1), ('homens', 'Reunião', 2), ('homens', 'Culto que servimos', 3), ('homens', 'Outro', 4),
  ('mulheres', 'Ensaio', 1), ('mulheres', 'Reunião', 2), ('mulheres', 'Culto que servimos', 3), ('mulheres', 'Outro', 4),
  ('coral', 'Ensaio', 1), ('coral', 'Reunião', 2), ('coral', 'Culto que servimos', 3), ('coral', 'Outro', 4),
  ('danca', 'Ensaio', 1), ('danca', 'Reunião', 2), ('danca', 'Culto que servimos', 3), ('danca', 'Outro', 4),
  ('diaconos', 'Ensaio', 1), ('diaconos', 'Reunião', 2), ('diaconos', 'Culto que servimos', 3), ('diaconos', 'Outro', 4),
  ('intercessao', 'Ensaio', 1), ('intercessao', 'Reunião', 2), ('intercessao', 'Culto que servimos', 3), ('intercessao', 'Outro', 4),
  ('louvor', 'Ensaio', 1), ('louvor', 'Reunião', 2), ('louvor', 'Culto que servimos', 3), ('louvor', 'Outro', 4),
  ('midia', 'Ensaio', 1), ('midia', 'Reunião', 2), ('midia', 'Culto que servimos', 3), ('midia', 'Outro', 4),
  ('multimidia', 'Ensaio', 1), ('multimidia', 'Reunião', 2), ('multimidia', 'Culto que servimos', 3), ('multimidia', 'Outro', 4),
  ('teatro', 'Ensaio', 1), ('teatro', 'Reunião', 2), ('teatro', 'Culto que servimos', 3), ('teatro', 'Outro', 4)
) as t(ministerio, tipo, ordem)
on conflict (ministerio, nome) do nothing;

create table if not exists public.ocasioes_ministerio (
  id uuid primary key default gen_random_uuid(),
  ministerio text not null,
  tipo text not null,
  data date not null,
  criado_por uuid references public.profiles(id),
  criado_em timestamptz not null default now(),
  unique (ministerio, tipo, data)
);

alter table public.ocasioes_ministerio enable row level security;
drop policy if exists "ocasioes_ministerio_select" on public.ocasioes_ministerio;
create policy "ocasioes_ministerio_select" on public.ocasioes_ministerio
  for select using (is_admin() or is_lider_ministerio(ministerio));

create table if not exists public.presencas_ministerio (
  id uuid primary key default gen_random_uuid(),
  ocasiao_id uuid not null references public.ocasioes_ministerio(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  criado_por uuid references public.profiles(id),
  criado_em timestamptz not null default now(),
  unique (ocasiao_id, profile_id)
);

alter table public.presencas_ministerio enable row level security;
drop policy if exists "presencas_ministerio_select" on public.presencas_ministerio;
create policy "presencas_ministerio_select" on public.presencas_ministerio
  for select using (
    is_admin()
    or exists (
      select 1 from public.ocasioes_ministerio o
      where o.id = ocasiao_id and is_lider_ministerio(o.ministerio)
    )
  );

-- Check-in em massa: cria (ou reaproveita) a ocasiao de HOJE pra esse
-- ministerio+tipo, e registra presenca de cada profile_id passado --
-- SO' de quem realmente e' membro daquele ministerio (profile_ministerios),
-- ignorando silenciosamente quem nao e' (o app ja filtra isso ao
-- buscar via buscar_pessoas_ministerio, mas a funcao confere de novo
-- aqui por seguranca).
create or replace function public.checkin_em_massa_ministerio(
  p_ministerio text,
  p_tipo_ocasiao text,
  p_profile_ids uuid[]
)
returns uuid
language plpgsql security definer set search_path = public
as $func$
declare
  v_ocasiao_id uuid;
  v_profile_id uuid;
begin
  if not (is_admin() or is_lider_ministerio(p_ministerio)) then
    raise exception 'Só líder do ministério ou admin pode fazer check-in.';
  end if;

  insert into public.ocasioes_ministerio (ministerio, tipo, data, criado_por)
  values (p_ministerio, p_tipo_ocasiao, (now() at time zone 'America/Sao_Paulo')::date, auth.uid())
  on conflict (ministerio, tipo, data) do update set ministerio = excluded.ministerio
  returning id into v_ocasiao_id;

  foreach v_profile_id in array p_profile_ids loop
    if exists (
      select 1 from public.profile_ministerios
      where profile_id = v_profile_id and ministerio = p_ministerio
    ) then
      insert into public.presencas_ministerio (ocasiao_id, profile_id, criado_por)
      values (v_ocasiao_id, v_profile_id, auth.uid())
      on conflict (ocasiao_id, profile_id) do nothing;
    end if;
  end loop;

  return v_ocasiao_id;
end;
$func$;

select 'ocasioes_ministerio + presencas_ministerio + checkin_em_massa_ministerio criados.' as status;
