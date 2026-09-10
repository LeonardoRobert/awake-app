-- Grupos de Casais (Henrique e Patricia, Ivaldo e Sonja, Marcelo e
-- Andreia, e outros que vierem a existir) passam a funcionar como
-- ministerios de verdade: cada grupo tem seu proprio "ministerio" (ver
-- profile_ministerios), pode ter lider, e entra no MESMO sistema de
-- check-in em massa ja construido em 2026_checkin_ministerio.sql -- sem
-- nenhum codigo novo pra check-in em si, so' dados.
--
-- A lista de grupos e' DINAMICA (tabela grupos_casais_catalogo, nao um
-- enum fixo) -- um admin pode inserir uma linha nova aqui a qualquer
-- momento pra criar mais um grupo, sem precisar de deploy novo.
--
-- Convencao: o "ministerio" de um grupo de casais e' sempre
-- 'casais_' || slug (ex: 'casais_henrique_patricia'), pra nunca colidir
-- com os ministerios ja existentes (homens, danca, etc).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create table if not exists public.grupos_casais_catalogo (
  slug text primary key,
  nome text not null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

alter table public.grupos_casais_catalogo enable row level security;

drop policy if exists "grupos_casais_catalogo_select" on public.grupos_casais_catalogo;
create policy "grupos_casais_catalogo_select" on public.grupos_casais_catalogo
  for select using (true);

drop policy if exists "grupos_casais_catalogo_admin" on public.grupos_casais_catalogo;
create policy "grupos_casais_catalogo_admin" on public.grupos_casais_catalogo
  for all using (is_admin()) with check (is_admin());

-- Sempre que um grupo novo e' cadastrado no catalogo, ja semeia o
-- catalogo de ocasioes (Ensaio/Reuniao/Culto que servimos/Outro) pra
-- ele -- mesmo padrao generico usado pros outros 10 ministerios, sem
-- precisar de mais nenhum passo manual.
create or replace function public.seed_ocasioes_catalogo_grupo_casais()
returns trigger
language plpgsql security definer set search_path = public
as $func$
begin
  insert into public.ocasioes_ministerio_catalogo (ministerio, nome, ordem)
  values
    ('casais_' || new.slug, 'Ensaio', 1),
    ('casais_' || new.slug, 'Reunião', 2),
    ('casais_' || new.slug, 'Culto que servimos', 3),
    ('casais_' || new.slug, 'Outro', 4)
  on conflict (ministerio, nome) do nothing;
  return new;
end;
$func$;

drop trigger if exists trg_seed_ocasioes_catalogo_grupo_casais on public.grupos_casais_catalogo;
create trigger trg_seed_ocasioes_catalogo_grupo_casais
  after insert on public.grupos_casais_catalogo
  for each row execute function public.seed_ocasioes_catalogo_grupo_casais();

-- Grupos ja existentes hoje (profiles.grupo_casais ja usa esses slugs) --
-- o insert abaixo dispara o trigger acima e ja semeia as ocasioes deles.
insert into public.grupos_casais_catalogo (slug, nome) values
  ('henrique_patricia', 'Grupo do Henrique e Patrícia'),
  ('ivaldo_sonja', 'Grupo do Ivaldo e Sonja'),
  ('marcelo_andreia', 'Grupo do Marcelo e Andréia')
on conflict (slug) do nothing;

-- Sempre que profiles.grupo_casais e' definido/alterado (pelo app OU
-- por edicao direta no banco), mantem profile_ministerios sincronizado
-- -- e' o que faz a pessoa "aparecer" como membro daquele grupo pro
-- check-in reconhecer, e permite promove-la a lider dali (gestao.html
-- ja faz isso pra qualquer ministerio em profile_ministerios).
create or replace function public.sync_profile_ministerios_grupo_casais()
returns trigger
language plpgsql security definer set search_path = public
as $func$
begin
  if new.grupo_casais is not null
     and (tg_op = 'INSERT' or new.grupo_casais is distinct from old.grupo_casais) then
    insert into public.profile_ministerios (profile_id, ministerio, papel)
    values (new.id, 'casais_' || new.grupo_casais, 'membro')
    on conflict (profile_id, ministerio) do nothing;
  end if;

  -- Se a pessoa trocou de grupo, tira o vinculo do grupo antigo -- mas
  -- NUNCA mexe se o vinculo antigo for de lider (evita que uma edicao
  -- de perfil derrube lideranca sem querer; nesse caso um admin remove
  -- manualmente no gestao se for o caso).
  if tg_op = 'UPDATE' and old.grupo_casais is not null
     and old.grupo_casais is distinct from new.grupo_casais then
    delete from public.profile_ministerios
    where profile_id = old.id
      and ministerio = 'casais_' || old.grupo_casais
      and papel = 'membro';
  end if;

  return new;
end;
$func$;

-- IMPORTANTE: "after update" sem "of grupo_casais" de proposito. Ja
-- existe um outro trigger (trg_limpar_grupo_casais_ao_sair_de_casado,
-- ver 2026_limpar_grupo_casais_ao_descasar.sql) que zera grupo_casais
-- como efeito colateral de um UPDATE que so' mexe em estado_civil -- um
-- trigger "of grupo_casais" NAO dispara nesse caso (o Postgres decide
-- se dispara pela lista de colunas do UPDATE original, nao pelo valor
-- final depois de outros triggers BEFORE mexerem nele). Sem a coluna
-- especifica, este trigger roda em todo UPDATE de profiles e a funcao
-- acima ja se vira sozinha com o "is distinct from" pra nao fazer nada
-- quando grupo_casais nao mudou de verdade.
drop trigger if exists trg_sync_profile_ministerios_grupo_casais on public.profiles;
create trigger trg_sync_profile_ministerios_grupo_casais
  after insert or update on public.profiles
  for each row execute function public.sync_profile_ministerios_grupo_casais();

-- Backfill unico: quem ja tem grupo_casais preenchido hoje (de antes
-- desse trigger existir) ganha o vinculo em profile_ministerios agora.
insert into public.profile_ministerios (profile_id, ministerio, papel)
select id, 'casais_' || grupo_casais, 'membro'
from public.profiles
where grupo_casais is not null
on conflict (profile_id, ministerio) do nothing;

select 'grupos_casais_catalogo criado + sincronizacao com profile_ministerios ativa.' as status;
