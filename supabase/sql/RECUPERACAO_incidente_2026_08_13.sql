-- =========================================================
-- RECUPERACAO do incidente de 13/08/2026: schema.sql (script antigo
-- de "recriar do zero") foi rodado por engano contra o banco de
-- producao e derrubou profiles, eventos, escalas, inscricoes,
-- checkins, areas_servico e lider_config.
--
-- Rode esse arquivo INTEIRO, de uma vez, no SQL Editor.
--
-- O que NAO precisa disso porque sobreviveu: auth.users (8 contas),
-- contribuicoes (5), escala_servico_posicoes (79), profile_ministerios
-- (10), presencas_eventos (1). Esses dados ja guardam o profile_id
-- certo -- assim que profiles existir nos MESMOS ids de auth.users,
-- eles reconectam sozinhos.
--
-- O que NAO da pra recuperar por aqui (schema so guarda estrutura, nao
-- dado apagado): os EVENTOS de verdade que existiam (titulo, data,
-- etc) -- precisam ser recriados manualmente, um por um, no Calendario.
-- Detalhes de perfil que so existiam em profiles (telefone, endereco,
-- data de nascimento, estado civil, foto) tambem sumiram -- cada
-- pessoa precisa preencher de novo em "Editar Perfil".
-- =========================================================

-- ---------------------------------------------------------
-- 1) TABELA profiles (estrutura atual, nao a do schema.sql antigo --
--    papel agora e text+check em vez de enum, pra caber
--    'admin_financeiro' sem precisar de ALTER TYPE no futuro)
-- ---------------------------------------------------------
drop table if exists public.profiles cascade;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null default '',
  telefone text,
  endereco text,
  data_nascimento date,
  tempo_participacao text,
  estado_civil text check (estado_civil is null or estado_civil in ('solteiro', 'namorando', 'noivo', 'casado', 'outro')),
  sexo text check (sexo is null or sexo in ('masculino', 'feminino')),
  grupo_casais text check (grupo_casais is null or grupo_casais in ('henrique_patricia', 'ivaldo_sonja', 'marcelo_andreia')),
  foto_url text,
  categoria text check (categoria is null or categoria in ('genesis', 'next', 'one')),
  papel text not null default 'membro' check (papel in ('membro', 'admin', 'admin_financeiro')),
  qr_code_id uuid not null default gen_random_uuid(),
  ativo boolean not null default true,
  tour_visto boolean not null default false,
  valor_dizimo_padrao numeric,
  eh_conta_teste boolean not null default false,
  criado_em timestamptz not null default now()
);

create index idx_profiles_conta_teste on public.profiles (id) where eh_conta_teste = true;

-- ---------------------------------------------------------
-- 2) TABELA eventos (estrutura atual)
-- ---------------------------------------------------------
drop table if exists public.eventos cascade;

create table public.eventos (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  descricao text,
  data_inicio timestamptz not null,
  data_fim timestamptz,
  local text,
  criado_por uuid references public.profiles (id),
  recorrente boolean not null default false,
  recorrencia_fim date,
  semanas_do_mes int[],
  tipo text not null default 'outro',
  escopo text not null default 'igreja',
  publico_alvo text[],
  publico_genero text[],
  publico_casais text[],
  excecoes timestamptz[] not null default '{}',
  foto_url text,
  foto_story_url text,
  ingressado boolean not null default false,
  valor_total numeric,
  parcelas_sugeridas int,
  metodos_pagamento text[],
  criado_em timestamptz not null default now()
);

-- View publica usada pelo site.html (sem login) -- so os escopos que
-- ja apareciam na agenda publica antes.
create view public.eventos_publicos as
select * from public.eventos where escopo in ('igreja', 'homens', 'mulheres', 'awake');

-- ---------------------------------------------------------
-- 3) Repovoa os 4 usuarios reais -- nome recuperado de
--    auth.users.raw_user_meta_data (sobreviveu ao incidente).
--    Papel/grupo_casais preenchidos com o que se sabe; o resto (telefone,
--    endereco, nascimento, estado civil, foto) precisa ser preenchido
--    de novo por cada pessoa em "Editar Perfil".
-- ---------------------------------------------------------
insert into public.profiles (id, nome, papel, grupo_casais) values
  ('fdf388e2-395f-4b52-a986-7c44c0008fee', 'Leonardo Robert Sant''Ana Campos', 'admin', null),
  ('9e5d1084-aa22-4da6-ba40-6be66acf39f6', 'Sérgio Fonseca Campos', 'membro', 'henrique_patricia'),
  ('1b71b1b7-2e06-41e0-8abd-f50a457063cf', 'Sílvia Alves Sant''Ana Campos', 'membro', 'henrique_patricia'),
  ('294923d3-dced-4198-abbd-49de92ffb77e', 'Maria Victória de Carvalho Fontes dos Santos', 'membro', null);

-- ---------------------------------------------------------
-- 4) Reconecta as tabelas que sobreviveram -- a coluna profile_id/
--    criado_por/etc continua com o id certo, so faltava a tabela
--    profiles/eventos existir de novo. NOT VALID = nao trava agora se
--    sobrar alguma linha orfa (ex: contribuicoes.evento_id apontando
--    pra um evento que foi apagado e nao pode ser recriado com o
--    mesmo id) -- valida so as linhas novas dai pra frente.
-- ---------------------------------------------------------
alter table public.contribuicoes add constraint contribuicoes_profile_id_fkey foreign key (profile_id) references public.profiles(id) not valid;
alter table public.contribuicoes add constraint contribuicoes_lancado_por_fkey foreign key (lancado_por) references public.profiles(id) not valid;
alter table public.contribuicoes add constraint contribuicoes_evento_id_fkey foreign key (evento_id) references public.eventos(id) not valid;

alter table public.escala_servico_casais add constraint escala_servico_casais_profile_id_a_fkey foreign key (profile_id_a) references public.profiles(id) not valid;
alter table public.escala_servico_casais add constraint escala_servico_casais_profile_id_b_fkey foreign key (profile_id_b) references public.profiles(id) not valid;
alter table public.escala_servico_casais add constraint escala_servico_casais_criado_por_fkey foreign key (criado_por) references public.profiles(id) not valid;

alter table public.escala_servico_posicoes add constraint escala_servico_posicoes_profile_id_fkey foreign key (profile_id) references public.profiles(id) not valid;
alter table public.escala_servico_posicoes add constraint escala_servico_posicoes_profile_id_2_fkey foreign key (profile_id_2) references public.profiles(id) not valid;

alter table public.escalas_servico add constraint escalas_servico_criado_por_fkey foreign key (criado_por) references public.profiles(id) not valid;
alter table public.escalas_servico add constraint escalas_servico_evento_id_fkey foreign key (evento_id) references public.eventos(id) not valid;

alter table public.filhos add constraint filhos_responsavel_id_fkey foreign key (responsavel_id) references public.profiles(id) not valid;

alter table public.pedidos_oracao add constraint pedidos_oracao_profile_id_fkey foreign key (profile_id) references public.profiles(id) not valid;

alter table public.profile_ministerios add constraint profile_ministerios_profile_id_fkey foreign key (profile_id) references public.profiles(id) not valid;

alter table public.testemunhos add constraint testemunhos_profile_id_fkey foreign key (profile_id) references public.profiles(id) not valid;

alter table public.transacoes_bancarias add constraint transacoes_bancarias_profile_id_fkey foreign key (profile_id) references public.profiles(id) not valid;

alter table public.visitantes_primeira_vez add constraint visitantes_primeira_vez_registrado_por_fkey foreign key (registrado_por) references public.profiles(id) not valid;

alter table public.eventos_lembretes_enviados add constraint eventos_lembretes_enviados_evento_id_fkey foreign key (evento_id) references public.eventos(id) not valid;

alter table public.presencas_eventos add constraint presencas_eventos_evento_id_fkey foreign key (evento_id) references public.eventos(id) not valid;

-- ---------------------------------------------------------
-- 5) Funcoes basicas
-- ---------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql security definer set search_path = public stable
as $$ select exists (select 1 from public.profiles where id = auth.uid() and papel = 'admin'); $$;

create or replace function public.is_admin_financeiro()
returns boolean language sql security definer set search_path = public stable
as $$ select exists (select 1 from public.profiles where id = auth.uid() and papel = 'admin_financeiro'); $$;

create or replace function public.calcular_categoria()
returns trigger language plpgsql
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
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nome, papel)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'nome', ''), 'membro');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------
-- 6) RLS basico (profiles/eventos) -- amplo mas seguro: qualquer
--    logado le, so admin/admin_financeiro/dono escreve. As policies
--    RESTRITIVAS de conta de teste e o acesso por lideranca de
--    ministerio voltam no passo 8 (arquivos ja existentes, so re-rodar).
-- ---------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.eventos enable row level security;

-- Amplo de proposito: o app ja depende de qualquer logado conseguir
-- buscar outras pessoas por nome (check-in, autocomplete de escala,
-- etc) -- restringir pra so admin quebraria essas telas.
create policy "profiles_select" on public.profiles
  for select using (auth.uid() is not null);

create policy "profiles_update_self" on public.profiles
  for update using (id = auth.uid());

create policy "profiles_update_admin" on public.profiles
  for update using (is_admin() or is_admin_financeiro());

create policy "eventos_select" on public.eventos
  for select using (auth.uid() is not null);

create policy "eventos_select_publico" on public.eventos
  for select to anon using (escopo in ('igreja', 'homens', 'mulheres', 'awake'));

create policy "eventos_insert" on public.eventos
  for insert with check (is_admin());

create policy "eventos_update" on public.eventos
  for update using (is_admin());

create policy "eventos_delete" on public.eventos
  for delete using (is_admin());

-- fim
select 'Reconstrucao de profiles/eventos concluida. Falta rodar os 4 arquivos do passo 8.' as status;
