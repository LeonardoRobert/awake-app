-- =========================================================
-- RECUPERACAO parte 2: escalas/inscricoes/checkins (sistema "Escala
-- Awake" de voluntariado com vagas + check-in por QR Code) e as FKs
-- que faltavam em presencas_eventos.
--
-- Erro real descoberto: eu tinha assumido que escalas/inscricoes
-- eram sistema morto (0 linhas) e deixado como o schema.sql antigo
-- recriou -- mas o codigo atual (shift_service.dart, checkin_service.
-- dart) evoluiu essas tabelas bem alem disso (coluna data_ocorrencia
-- em inscricoes, RPCs novas com assinatura diferente). Essa parte
-- corrige pra estrutura de verdade que o app espera hoje.
-- =========================================================

-- ---------------------------------------------------------
-- 1) presencas_eventos -- so faltavam as FKs (a tabela em si
--    sobreviveu ao incidente com a estrutura certa).
-- ---------------------------------------------------------
alter table public.presencas_eventos add constraint presencas_eventos_user_id_fkey foreign key (user_id) references public.profiles(id) not valid;
alter table public.presencas_eventos add constraint presencas_eventos_feito_por_fkey foreign key (feito_por) references public.profiles(id) not valid;

-- ---------------------------------------------------------
-- 2) escalas -- tinha 0 linhas, recria limpa com a estrutura atual
--    (ganhou "nome" e "excecoes" desde o schema.sql antigo).
-- ---------------------------------------------------------
drop table if exists public.escalas cascade;

create table public.escalas (
  id uuid primary key default gen_random_uuid(),
  nome text not null default '',
  area_id uuid references public.areas_servico (id),
  data date not null,
  horario_inicio time not null,
  horario_fim time not null,
  vagas int not null default 1,
  recorrente boolean not null default false,
  recorrencia_fim date,
  excecoes date[] not null default '{}',
  criado_por uuid references public.profiles (id),
  criado_em timestamptz not null default now()
);

-- ---------------------------------------------------------
-- 3) inscricoes -- tinha 0 linhas, recria com data_ocorrencia (nao
--    existia no schema.sql antigo). Unique agora inclui data_ocorrencia
--    -- a mesma pessoa pode se inscrever em semanas diferentes da
--    mesma escala recorrente, so nao pode duplicar a MESMA ocorrencia.
-- ---------------------------------------------------------
drop table if exists public.inscricoes cascade;

create table public.inscricoes (
  id uuid primary key default gen_random_uuid(),
  escala_id uuid not null references public.escalas (id) on delete cascade,
  data_ocorrencia date not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'inscrito'
    check (status in ('inscrito', 'cancelado_no_prazo', 'cancelado_fora_prazo', 'check_in_feito', 'faltou')),
  inscrito_em timestamptz not null default now(),
  cancelado_em timestamptz,
  unique (escala_id, user_id, data_ocorrencia)
);

-- ---------------------------------------------------------
-- 4) checkins -- estrutura igual a de antes, so garante a FK certa.
-- ---------------------------------------------------------
drop table if exists public.checkins cascade;

create table public.checkins (
  id uuid primary key default gen_random_uuid(),
  inscricao_id uuid not null unique references public.inscricoes (id) on delete cascade,
  feito_por uuid references public.profiles (id),
  checkin_em timestamptz not null default now()
);

-- ---------------------------------------------------------
-- 5) RPCs -- reconstruidas com a MESMA logica de negocio de antes
--    (limite de 2 domingos/mes, checagem de vagas, janela de 24h pra
--    cancelamento sem penalidade), so com as assinaturas novas que o
--    app usa hoje (com p_data_ocorrencia). Testa com calma -- e uma
--    reconstrucao, nao uma copia exata do original.
-- ---------------------------------------------------------
create or replace function public.inscrever_em_escala(p_escala_id uuid, p_data_ocorrencia date)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_vagas int;
  v_inscritos int;
  v_domingos_no_mes int;
  v_nova_inscricao_id uuid;
begin
  select vagas into v_vagas from public.escalas where id = p_escala_id;
  if v_vagas is null then
    raise exception 'Escala nao encontrada';
  end if;

  select count(*) into v_inscritos
  from public.inscricoes
  where escala_id = p_escala_id and data_ocorrencia = p_data_ocorrencia
    and status in ('inscrito', 'check_in_feito');

  if v_inscritos >= v_vagas then
    raise exception 'Esta escala ja esta lotada';
  end if;

  if extract(dow from p_data_ocorrencia) = 0 then
    select count(*) into v_domingos_no_mes
    from public.inscricoes i
    where i.user_id = auth.uid()
      and i.status in ('inscrito', 'check_in_feito')
      and extract(dow from i.data_ocorrencia) = 0
      and date_trunc('month', i.data_ocorrencia) = date_trunc('month', p_data_ocorrencia);

    if v_domingos_no_mes >= 2 then
      raise exception 'Voce ja atingiu o limite de 2 domingos neste mes';
    end if;
  end if;

  insert into public.inscricoes (escala_id, data_ocorrencia, user_id)
  values (p_escala_id, p_data_ocorrencia, auth.uid())
  returning id into v_nova_inscricao_id;

  return v_nova_inscricao_id;
end;
$$;

create or replace function public.cancel_signup(p_inscricao_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_user_id uuid;
  v_data_ocorrencia date;
  v_horario_inicio time;
  v_inicio_escala timestamptz;
  v_novo_status text;
begin
  select i.user_id, i.data_ocorrencia, e.horario_inicio
    into v_user_id, v_data_ocorrencia, v_horario_inicio
  from public.inscricoes i
  join public.escalas e on e.id = i.escala_id
  where i.id = p_inscricao_id;

  if v_user_id is null then
    raise exception 'Inscricao nao encontrada';
  end if;

  if v_user_id <> auth.uid() and not (public.is_admin() or public.is_lider_de_algum_ministerio()) then
    raise exception 'Sem permissao para cancelar esta inscricao';
  end if;

  v_inicio_escala := (v_data_ocorrencia + v_horario_inicio)::timestamptz;

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

-- Contagem SEM identificar quem se inscreveu -- usada pra todo mundo
-- ver quantas vagas ja foram preenchidas mesmo sem RLS deixar ver as
-- inscricoes dos outros.
create or replace function public.contar_inscritos_geral()
returns table (escala_id uuid, data_ocorrencia date, total bigint)
language sql security definer set search_path = public stable
as $$
  select i.escala_id, i.data_ocorrencia, count(*) as total
  from public.inscricoes i
  where i.status in ('inscrito', 'check_in_feito')
  group by i.escala_id, i.data_ocorrencia;
$$;

create or replace function public.excluir_ocorrencia_escala(p_escala_id uuid, p_data date)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not (public.is_admin() or public.is_lider_de_algum_ministerio()) then
    raise exception 'Sem permissao';
  end if;

  update public.escalas
  set excecoes = array_append(coalesce(excecoes, '{}'), p_data)
  where id = p_escala_id;

  update public.inscricoes
  set status = 'cancelado_fora_prazo', cancelado_em = now()
  where escala_id = p_escala_id and data_ocorrencia = p_data
    and status in ('inscrito', 'check_in_feito');
end;
$$;

create or replace function public.check_in_member(p_qr_code_id uuid, p_escala_id uuid, p_data_ocorrencia date)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_member_id uuid;
  v_member_nome text;
  v_inscricao_id uuid;
begin
  if not (public.is_admin() or public.is_lider_de_algum_ministerio()) then
    raise exception 'Apenas lideres podem fazer check-in';
  end if;

  select id, nome into v_member_id, v_member_nome
  from public.profiles where qr_code_id = p_qr_code_id;

  if v_member_id is null then
    raise exception 'QR Code invalido';
  end if;

  select id into v_inscricao_id
  from public.inscricoes
  where escala_id = p_escala_id and data_ocorrencia = p_data_ocorrencia
    and user_id = v_member_id and status = 'inscrito';

  if v_inscricao_id is null then
    raise exception '% nao esta inscrito(a) nesta escala', v_member_nome;
  end if;

  insert into public.checkins (inscricao_id, feito_por)
  values (v_inscricao_id, auth.uid());

  update public.inscricoes set status = 'check_in_feito' where id = v_inscricao_id;

  return v_member_nome;
end;
$$;

create or replace function public.check_in_evento(p_qr_code_id uuid, p_evento_id uuid, p_data_ocorrencia date)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_member_id uuid;
  v_member_nome text;
begin
  if not (public.is_admin() or public.is_lider_de_algum_ministerio()) then
    raise exception 'Apenas lideres podem fazer check-in';
  end if;

  select id, nome into v_member_id, v_member_nome
  from public.profiles where qr_code_id = p_qr_code_id;

  if v_member_id is null then
    raise exception 'QR Code invalido';
  end if;

  insert into public.presencas_eventos (evento_id, data_ocorrencia, user_id, feito_por)
  values (p_evento_id, p_data_ocorrencia, v_member_id, auth.uid())
  on conflict do nothing;

  return v_member_nome;
end;
$$;

-- ---------------------------------------------------------
-- 6) RLS
-- ---------------------------------------------------------
alter table public.escalas enable row level security;
alter table public.inscricoes enable row level security;
alter table public.checkins enable row level security;
alter table public.areas_servico enable row level security;

drop policy if exists "escalas_select" on public.escalas;
create policy "escalas_select" on public.escalas for select using (auth.uid() is not null);
drop policy if exists "escalas_insert" on public.escalas;
create policy "escalas_insert" on public.escalas for insert with check (is_admin() or is_lider_de_algum_ministerio());
drop policy if exists "escalas_update" on public.escalas;
create policy "escalas_update" on public.escalas for update using (is_admin() or is_lider_de_algum_ministerio());
drop policy if exists "escalas_delete" on public.escalas;
create policy "escalas_delete" on public.escalas for delete using (is_admin() or is_lider_de_algum_ministerio());

drop policy if exists "inscricoes_select" on public.inscricoes;
create policy "inscricoes_select" on public.inscricoes
  for select using (user_id = auth.uid() or is_admin() or is_lider_de_algum_ministerio());

drop policy if exists "checkins_select" on public.checkins;
create policy "checkins_select" on public.checkins
  for select using (
    is_admin() or is_lider_de_algum_ministerio()
    or exists (select 1 from public.inscricoes i where i.id = inscricao_id and i.user_id = auth.uid())
  );

drop policy if exists "areas_select" on public.areas_servico;
create policy "areas_select" on public.areas_servico for select using (auth.uid() is not null);

select 'Parte 2 (escala/metas) concluida.' as status;
