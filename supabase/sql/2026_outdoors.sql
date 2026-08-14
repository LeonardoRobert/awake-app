-- Tabela dos "outdoors" -- banners que giram em slideshow na tela de
-- Inicio, acima da tarja de evento ingressado / "Proximos eventos".
--
-- tipo='recorrente': repete todo mes, baseado no Nº-esimo domingo do mes
-- (semana_do_mes, 1 a 5) -- a janela de visibilidade (5 dias antes do
-- domingo ate o fim do proprio domingo) e calculada no APP
-- (lib/models/outdoor_model.dart), nao aqui no banco, pelo mesmo motivo
-- que a recorrencia de eventos (semanas_do_mes) tambem e calculada no
-- Dart (EventModel.occurrencesBetween) -- e "hoje" muda todo dia, nao da
-- pra fixar isso numa policy estatica.
-- tipo='temporario': fica visivel continuamente entre data_inicio e
-- data_fim (inclusive).
-- tipo='sempre': outdoor fixo, sem nenhuma janela de data -- fica
-- visivel o tempo todo, so controlado pelo toggle "ativo". Adicionado
-- depois do resto da tabela -- por isso os constraints de tipo ficam
-- fora do create table (via ALTER, idempotente), pra esse arquivo
-- poder ser re-rodado sem erro mesmo se a tabela ja existir de uma
-- versao anterior (so com 'recorrente'/'temporario').
create table if not exists public.outdoors (
  id uuid primary key default gen_random_uuid(),
  imagem_url text not null,
  link_url text,
  tipo text not null,
  semana_do_mes int check (semana_do_mes between 1 and 5),
  data_inicio date,
  data_fim date,
  ativo boolean not null default true,
  -- Escopos/ministerios que podem ver esse outdoor -- mesmo vocabulario
  -- de eventos.escopo (ver ordemEscopos em event_model.dart). null ou
  -- array vazio = visivel pra todo mundo.
  escopos text[],
  criado_por uuid references public.profiles(id),
  criado_em timestamptz not null default now()
);

alter table public.outdoors drop constraint if exists outdoors_tipo_check;
alter table public.outdoors add constraint outdoors_tipo_check
  check (tipo in ('recorrente', 'temporario', 'sempre'));

alter table public.outdoors drop constraint if exists outdoors_recorrente_precisa_semana;
alter table public.outdoors add constraint outdoors_recorrente_precisa_semana
  check (tipo <> 'recorrente' or semana_do_mes is not null);

alter table public.outdoors drop constraint if exists outdoors_temporario_precisa_periodo;
alter table public.outdoors add constraint outdoors_temporario_precisa_periodo
  check (tipo <> 'temporario' or (data_inicio is not null and data_fim is not null));

alter table public.outdoors enable row level security;

-- Espelha a mesma logica de audiencia de eventos_select
-- (RECUPERACAO_parte6/7), mas percorrendo o array `escopos` em vez de
-- uma coluna unica -- SEM os sub-filtros de genero/categoria que
-- eventos tem dentro de Awake/Coral/Casais (aqui e so nivel
-- ministerio/escopo, conforme combinado). Admin ve tudo (inclusive
-- pausado) pra conseguir gerenciar; os demais so veem outdoor ativo e
-- dentro do publico certo.
drop policy if exists "outdoors_select" on public.outdoors;
create policy "outdoors_select" on public.outdoors
  for select using (
    is_admin()
    or (
      ativo
      and (
        escopos is null
        or array_length(escopos, 1) is null
        or exists (select 1 from unnest(escopos) as esc where esc = 'igreja')
        or exists (select 1 from unnest(escopos) as esc where esc in ('criancas', 'embaixadores_mensageiras'))
        or exists (
          select 1 from unnest(escopos) as esc
          join public.profile_ministerios pm on pm.ministerio = esc
          where pm.profile_id = auth.uid()
        )
        or (
          exists (select 1 from unnest(escopos) as esc where esc = 'casais')
          and exists (select 1 from public.profiles p where p.id = auth.uid() and p.estado_civil = 'casado')
        )
        or (
          exists (select 1 from unnest(escopos) as esc where esc = 'lideranca')
          and exists (select 1 from public.profile_ministerios pm where pm.profile_id = auth.uid() and pm.papel = 'lider')
        )
      )
    )
  );

-- So admin cria/edita/apaga outdoor (diferente de eventos, onde lider de
-- ministerio tambem pode -- aqui nao, por pedido explicito do Leo).
drop policy if exists "outdoors_insert" on public.outdoors;
create policy "outdoors_insert" on public.outdoors
  for insert with check (is_admin());

drop policy if exists "outdoors_update" on public.outdoors;
create policy "outdoors_update" on public.outdoors
  for update using (is_admin());

drop policy if exists "outdoors_delete" on public.outdoors;
create policy "outdoors_delete" on public.outdoors
  for delete using (is_admin());

select 'Tabela outdoors criada.' as status;
