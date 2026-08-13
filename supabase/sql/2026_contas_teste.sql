-- Robo de teste automatizado: preparo das 4 contas de teste.
--
-- PASSO MANUAL PRIMEIRO (fora deste arquivo): crie as 4 contas em
-- Supabase Dashboard -> Authentication -> Users -> "Add user", com um
-- email dedicado por conta (ex: teste.membro@shallom.app,
-- teste.servico@shallom.app, teste.admin@shallom.app,
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
values ('f831cf0b-d5ac-4dd4-bd26-f1e60aaf94cd', '[TESTE] Membro', 'membro', true, true)
on conflict (id) do update set eh_conta_teste = true, nome = excluded.nome;

-- ===== Conta teste 2: Lider de TODAS as areas de servico =====
-- Nao e so Diaconos -- essa conta lidera as 5 areas de uma vez
-- (Diaconos, Louvor, Danca, Midia, Multimidia), pra o robo poder
-- testar a escala de qualquer uma delas com uma unica identidade, em
-- vez de precisar de uma conta por area.
insert into public.profiles (id, nome, papel, ativo, eh_conta_teste)
values ('c712dc5f-4d61-4d19-8e1a-0e1c37829b76', '[TESTE] Líder Áreas de Serviço', 'membro', true, true)
on conflict (id) do update set eh_conta_teste = true, nome = excluded.nome;

-- Sem constraint unica em (profile_id, ministerio) na tabela real --
-- por isso o upsert aqui e feito na mao (update se existir, senao
-- insere), em vez de "on conflict". Repete pras 5 areas de uma vez via
-- cross join, em vez de copiar o bloco 5x.
update public.profile_ministerios pm
set papel = 'lider'
from (values ('diaconos'), ('louvor'), ('danca'), ('midia'), ('multimidia')) as areas(ministerio)
where pm.profile_id = 'c712dc5f-4d61-4d19-8e1a-0e1c37829b76' and pm.ministerio = areas.ministerio;

insert into public.profile_ministerios (profile_id, ministerio, papel)
select 'c712dc5f-4d61-4d19-8e1a-0e1c37829b76', areas.ministerio, 'lider'
from (values ('diaconos'), ('louvor'), ('danca'), ('midia'), ('multimidia')) as areas(ministerio)
where not exists (
  select 1 from public.profile_ministerios
  where profile_id = 'c712dc5f-4d61-4d19-8e1a-0e1c37829b76' and ministerio = areas.ministerio
);

-- Confira o resultado:
select ministerio, papel from public.profile_ministerios
where profile_id = 'c712dc5f-4d61-4d19-8e1a-0e1c37829b76' order by ministerio;

-- ===== Conta teste 3: Admin =====
insert into public.profiles (id, nome, papel, ativo, eh_conta_teste)
values ('7696cd8a-cecb-4160-9b70-10a34f70b37e', '[TESTE] Admin', 'admin', true, true)
on conflict (id) do update set eh_conta_teste = true, papel = 'admin', nome = excluded.nome;

-- ===== Conta teste 4: Admin Financeiro =====
insert into public.profiles (id, nome, papel, ativo, eh_conta_teste)
values ('e7ea1328-505f-4c27-ba34-13e02896a402', '[TESTE] Admin Financeiro', 'admin_financeiro', true, true)
on conflict (id) do update set eh_conta_teste = true, papel = 'admin_financeiro', nome = excluded.nome;
