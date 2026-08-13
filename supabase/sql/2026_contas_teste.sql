-- Robo de teste automatizado: preparo das 4 contas de teste.
--
-- PASSO MANUAL PRIMEIRO (fora deste arquivo): crie as 4 contas em
-- Supabase Dashboard -> Authentication -> Users -> "Add user", com um
-- email dedicado por conta (ex: teste.membro@shallom.app,
-- teste.diaconos@shallom.app, teste.admin@shallom.app,
-- teste.financeiro@shallom.app) e senha forte. Anote os UUIDs gerados
-- (aparecem na lista de Users) -- vao entrar nos <<...>> abaixo.
--
-- Depois disso, cole este SQL no SQL Editor com os UUIDs reais no
-- lugar dos placeholders.

alter table public.profiles
  add column if not exists eh_conta_teste boolean not null default false;

-- Indice parcial -- so indexa as poucas linhas de teste, quase de
-- graca, e acelera qualquer "where eh_conta_teste" que a filtragem de
-- RLS for usar.
create index if not exists idx_profiles_conta_teste
  on public.profiles (id)
  where eh_conta_teste = true;

-- ===== Conta teste 1: Membro comum =====
insert into public.profiles (id, nome, papel, ativo, eh_conta_teste)
values ('<<uuid-teste-membro>>', '[TESTE] Membro', 'membro', true, true)
on conflict (id) do update set eh_conta_teste = true, nome = excluded.nome;

-- ===== Conta teste 2: Lider de Diaconos =====
insert into public.profiles (id, nome, papel, ativo, eh_conta_teste)
values ('<<uuid-teste-diaconos>>', '[TESTE] Lider Diaconos', 'membro', true, true)
on conflict (id) do update set eh_conta_teste = true, nome = excluded.nome;

-- Sem constraint unica em (profile_id, ministerio) na tabela real --
-- por isso o upsert aqui e feito na mao (update se existir, senao
-- insere), em vez de "on conflict".
update public.profile_ministerios
set papel = 'lider'
where profile_id = '<<uuid-teste-diaconos>>' and ministerio = 'diaconos';

insert into public.profile_ministerios (profile_id, ministerio, papel)
select '<<uuid-teste-diaconos>>', 'diaconos', 'lider'
where not exists (
  select 1 from public.profile_ministerios
  where profile_id = '<<uuid-teste-diaconos>>' and ministerio = 'diaconos'
);

-- ===== Conta teste 3: Admin =====
insert into public.profiles (id, nome, papel, ativo, eh_conta_teste)
values ('<<uuid-teste-admin>>', '[TESTE] Admin', 'admin', true, true)
on conflict (id) do update set eh_conta_teste = true, papel = 'admin', nome = excluded.nome;

-- ===== Conta teste 4: Admin Financeiro =====
insert into public.profiles (id, nome, papel, ativo, eh_conta_teste)
values ('<<uuid-teste-financeiro>>', '[TESTE] Admin Financeiro', 'admin_financeiro', true, true)
on conflict (id) do update set eh_conta_teste = true, papel = 'admin_financeiro', nome = excluded.nome;
