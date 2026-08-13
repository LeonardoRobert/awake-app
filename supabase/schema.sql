-- =========================================================
-- ⚠️ DESATUALIZADO — não reflete o banco de producao atual.
-- Varias tabelas foram criadas depois via SQL Editor e nunca
-- voltaram pra esse arquivo (contribuicoes, escala_servico_*,
-- pedidos_oracao, testemunhos, visitantes_primeira_vez,
-- profile_ministerios, transacoes_bancarias, entre outras).
-- O enum user_role aqui tambem esta velho (ainda tem 'lider'
-- como papel global e nao tem 'admin_financeiro').
-- NAO USE PRA RECRIAR O BANCO — so rode de novo depois de
-- substituir esse arquivo por um dump real (Supabase Database
-- -> Backups, ou pg_dump com a connection string do projeto).
-- =========================================================
-- Awake — Schema Supabase — VERSAO DEFINITIVA
-- Este script pode ser rodado quantas vezes precisar: ele sempre
-- limpa qualquer coisa que tenha ficado de tentativas anteriores
-- antes de reconstruir do zero. Nao tem risco de "ja existe".
-- =========================================================
-- Como usar: cole ISSO INTEIRO no SQL Editor do Supabase e clique Run.
-- =========================================================

-- ---------------------------------------------------------
-- LIMPEZA (remove qualquer coisa de tentativas anteriores)
-- ---------------------------------------------------------
drop trigger if exists on_auth_user_created on auth.users;

drop table if exists public.checkins cascade;
drop view if exists public.escalas_com_vagas cascade;
drop table if exists public.inscricoes cascade;
drop table if exists public.escalas cascade;
drop table if exists public.areas_servico cascade;
drop table if exists public.eventos cascade;
drop table if exists public.lider_config cascade;
drop table if exists public.profiles cascade;

drop function if exists public.check_in_member(uuid, uuid) cascade;
drop function if exists public.cancel_signup(uuid) cascade;
drop function if exists public.inscrever_em_escala(uuid) cascade;
drop function if exists public.solicitar_papel_lider(text) cascade;
drop function if exists public.set_leader_code(text) cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.is_lider_ou_admin() cascade;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.calcular_categoria() cascade;

drop type if exists categoria_type cascade;
drop type if exists estado_civil_type cascade;
drop type if exists signup_status cascade;
drop type if exists user_role cascade;

drop extension if exists pgcrypto;

-- ---------------------------------------------------------
-- RECONSTRUCAO
-- ---------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension pgcrypto with schema extensions;

create type user_role as enum ('membro', 'lider', 'admin');

create type estado_civil_type as enum (
  'solteiro', 'namorando', 'noivo', 'casado', 'outro'
);

create type categoria_type as enum ('genesis', 'next', 'one');

create type signup_status as enum (
  'inscrito', 'cancelado_no_prazo', 'cancelado_fora_prazo',
  'check_in_feito', 'faltou'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null default '',
  telefone text,
  endereco text,
  data_nascimento date,
  tempo_participacao text,
  estado_civil estado_civil_type,
  categoria categoria_type,
  papel user_role not null default 'membro',
  qr_code_id uuid not null default uuid_generate_v4(),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create or replace function public.calcular_categoria()
returns trigger
language plpgsql
as $$
declare
  v_idade int;
begin
  if new.estado_civil in ('noivo', 'casado') then
    new.categoria := 'one';
  elsif new.data_nascimento is not null then
    v_idade := extract(year from age(new.data_nascimento));
    if v_idade between 13 and 16 then
      new.categoria := 'genesis';
    elsif v_idade >= 17 then
      new.categoria := 'next';
    else
      new.categoria := null;
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_calcular_categoria
  before insert or update of data_nascimento, estado_civil on public.profiles
  for each row execute procedure public.calcular_categoria();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nome, papel)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'nome', ''), 'membro');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.is_lider_ou_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and papel in ('lider', 'admin')
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and papel = 'admin'
  );
$$;

create table public.lider_config (
  id boolean primary key default true,
  codigo_hash text not null,
  constraint lider_config_singleton check (id)
);

create or replace function public.set_leader_code(p_codigo text)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
begin
  insert into public.lider_config (id, codigo_hash)
  values (true, extensions.crypt(p_codigo, extensions.gen_salt('bf')))
  on conflict (id) do update set codigo_hash = excluded.codigo_hash;
end;
$$;

create or replace function public.solicitar_papel_lider(p_codigo text)
returns void
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_hash text;
begin
  select codigo_hash into v_hash from public.lider_config where id = true;

  if v_hash is null then
    raise exception 'Codigo de lider ainda nao foi configurado pelo admin';
  end if;

  if extensions.crypt(p_codigo, v_hash) <> v_hash then
    raise exception 'Codigo de lider invalido';
  end if;

  update public.profiles set papel = 'lider' where id = auth.uid();
end;
$$;

alter table public.lider_config enable row level security;

create table public.eventos (
  id uuid primary key default uuid_generate_v4(),
  titulo text not null,
  descricao text,
  data_inicio timestamptz not null,
  data_fim timestamptz,
  local text,
  criado_por uuid references public.profiles (id),
  criado_em timestamptz not null default now()
);

create table public.areas_servico (
  id uuid primary key default uuid_generate_v4(),
  nome text not null unique
);

create table public.escalas (
  id uuid primary key default uuid_generate_v4(),
  area_id uuid references public.areas_servico (id),
  data date not null,
  horario_inicio time not null,
  horario_fim time not null,
  vagas int not null default 1,
  criado_por uuid references public.profiles (id),
  criado_em timestamptz not null default now()
);

create table public.inscricoes (
  id uuid primary key default uuid_generate_v4(),
  escala_id uuid not null references public.escalas (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  status signup_status not null default 'inscrito',
  inscrito_em timestamptz not null default now(),
  cancelado_em timestamptz,
  unique (escala_id, user_id)
);

create view public.escalas_com_vagas as
select
  e.*,
  count(i.id) filter (
    where i.status in ('inscrito', 'check_in_feito')
  ) as inscritos_count
from public.escalas e
left join public.inscricoes i on i.escala_id = e.id
group by e.id;

create table public.checkins (
  id uuid primary key default uuid_generate_v4(),
  inscricao_id uuid not null unique references public.inscricoes (id) on delete cascade,
  feito_por uuid references public.profiles (id),
  checkin_em timestamptz not null default now()
);

create or replace function public.inscrever_em_escala(p_escala_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_data date;
  v_vagas int;
  v_inscritos int;
  v_domingos_no_mes int;
  v_nova_inscricao_id uuid;
begin
  select data, vagas into v_data, v_vagas
  from public.escalas where id = p_escala_id;

  if v_data is null then
    raise exception 'Escala nao encontrada';
  end if;

  select count(*) into v_inscritos
  from public.inscricoes
  where escala_id = p_escala_id and status in ('inscrito', 'check_in_feito');

  if v_inscritos >= v_vagas then
    raise exception 'Esta escala ja esta lotada';
  end if;

  if extract(dow from v_data) = 0 then
    select count(*) into v_domingos_no_mes
    from public.inscricoes i
    join public.escalas e on e.id = i.escala_id
    where i.user_id = auth.uid()
      and i.status in ('inscrito', 'check_in_feito')
      and extract(dow from e.data) = 0
      and date_trunc('month', e.data) = date_trunc('month', v_data);

    if v_domingos_no_mes >= 2 then
      raise exception 'Voce ja atingiu o limite de 2 domingos neste mes';
    end if;
  end if;

  insert into public.inscricoes (escala_id, user_id)
  values (p_escala_id, auth.uid())
  returning id into v_nova_inscricao_id;

  return v_nova_inscricao_id;
end;
$$;

create or replace function public.cancel_signup(p_inscricao_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid;
  v_inicio_escala timestamptz;
  v_novo_status signup_status;
begin
  select i.user_id, (e.data + e.horario_inicio)::timestamptz
    into v_user_id, v_inicio_escala
  from public.inscricoes i
  join public.escalas e on e.id = i.escala_id
  where i.id = p_inscricao_id;

  if v_user_id is null then
    raise exception 'Inscricao nao encontrada';
  end if;

  if v_user_id <> auth.uid() and not public.is_lider_ou_admin() then
    raise exception 'Sem permissao para cancelar esta inscricao';
  end if;

  if now() >= (v_inicio_escala - interval '24 hours') then
    v_novo_status := 'cancelado_fora_prazo';
  else
    v_novo_status := 'cancelado_no_prazo';
  end if;

  update public.inscricoes
  set status = v_novo_status, cancelado_em = now()
  where id = p_inscricao_id;
end;
$$;

create or replace function public.check_in_member(p_qr_code_id uuid, p_escala_id uuid)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  v_member_id uuid;
  v_member_nome text;
  v_inscricao_id uuid;
begin
  if not public.is_lider_ou_admin() then
    raise exception 'Apenas lideres podem fazer check-in';
  end if;

  select id, nome into v_member_id, v_member_nome
  from public.profiles
  where qr_code_id = p_qr_code_id;

  if v_member_id is null then
    raise exception 'QR Code invalido';
  end if;

  select id into v_inscricao_id
  from public.inscricoes
  where escala_id = p_escala_id and user_id = v_member_id and status = 'inscrito';

  if v_inscricao_id is null then
    raise exception '% nao esta inscrito(a) nesta escala', v_member_nome;
  end if;

  insert into public.checkins (inscricao_id, feito_por)
  values (v_inscricao_id, auth.uid());

  update public.inscricoes set status = 'check_in_feito' where id = v_inscricao_id;

  return v_member_nome;
end;
$$;

alter table public.profiles enable row level security;
alter table public.eventos enable row level security;
alter table public.areas_servico enable row level security;
alter table public.escalas enable row level security;
alter table public.inscricoes enable row level security;
alter table public.checkins enable row level security;

create policy "profiles_select" on public.profiles
  for select using (id = auth.uid() or public.is_lider_ou_admin());

create policy "profiles_update_self" on public.profiles
  for update using (id = auth.uid());

create policy "profiles_update_admin" on public.profiles
  for update using (public.is_admin());

create policy "eventos_select" on public.eventos
  for select using (auth.uid() is not null);

create policy "eventos_insert" on public.eventos
  for insert with check (public.is_lider_ou_admin());

create policy "eventos_update" on public.eventos
  for update using (public.is_lider_ou_admin());

create policy "eventos_delete" on public.eventos
  for delete using (public.is_lider_ou_admin());

create policy "areas_select" on public.areas_servico
  for select using (auth.uid() is not null);

create policy "areas_insert" on public.areas_servico
  for insert with check (public.is_admin());

create policy "areas_update" on public.areas_servico
  for update using (public.is_admin());

create policy "escalas_select" on public.escalas
  for select using (auth.uid() is not null);

create policy "escalas_insert" on public.escalas
  for insert with check (public.is_lider_ou_admin());

create policy "escalas_update" on public.escalas
  for update using (public.is_lider_ou_admin());

create policy "inscricoes_select" on public.inscricoes
  for select using (user_id = auth.uid() or public.is_lider_ou_admin());

create policy "checkins_select_lideres" on public.checkins
  for select using (public.is_lider_ou_admin());

create policy "checkins_select_proprio" on public.checkins
  for select using (
    exists (
      select 1 from public.inscricoes i
      where i.id = inscricao_id and i.user_id = auth.uid()
    )
  );

insert into public.areas_servico (nome) values
  ('Louvor'), ('Recepcao'), ('Midia'), ('Intercessao')
on conflict (nome) do nothing;

select public.set_leader_code('Despertar2026');