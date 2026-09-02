-- Corrige bug: EBD aparece nas duas abas (Awake e Shallom), mas o
-- "nao contabilizado" estava guardado direto em contagem_manual_eventos
-- por (evento, data) so' -- marcar como nao contabilizado numa aba
-- afetava a OUTRA aba tambem, sem querer. Move essa marcacao pra uma
-- tabela propria, com a aba como parte da chave.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

-- Reverte o que 2026_evento_nao_contabilizado.sql tinha feito nessa
-- tabela -- volta a ser so' a contagem manual da aba Shallom.
drop function if exists public.definir_nao_contabilizado_evento(uuid, date, boolean);
alter table public.contagem_manual_eventos drop column if exists nao_contabilizado;

create table if not exists public.ocorrencias_nao_contabilizadas (
  id uuid primary key default gen_random_uuid(),
  evento_id uuid not null references public.eventos(id) on delete cascade,
  data_ocorrencia date not null,
  aba text not null check (aba in ('awake', 'shallom')),
  criado_por uuid references public.profiles(id),
  criado_em timestamptz not null default now(),
  unique (evento_id, data_ocorrencia, aba)
);

alter table public.ocorrencias_nao_contabilizadas enable row level security;

drop policy if exists "ocorrencias_nao_contabilizadas_select" on public.ocorrencias_nao_contabilizadas;
create policy "ocorrencias_nao_contabilizadas_select" on public.ocorrencias_nao_contabilizadas
  for select using (is_admin());

-- Toggle: marca (insere) ou desmarca (apaga), sempre so' PRA AQUELA aba.
create or replace function public.definir_nao_contabilizado_evento(
  p_evento_id uuid,
  p_data_ocorrencia date,
  p_aba text,
  p_nao_contabilizado boolean
)
returns void
language plpgsql security definer set search_path = public
as $func$
begin
  if not is_admin() then
    raise exception 'Só admin pode marcar um evento como não contabilizado.';
  end if;
  if p_aba not in ('awake', 'shallom') then
    raise exception 'Aba inválida.';
  end if;

  if p_nao_contabilizado then
    insert into public.ocorrencias_nao_contabilizadas (evento_id, data_ocorrencia, aba, criado_por)
    values (p_evento_id, p_data_ocorrencia, p_aba, auth.uid())
    on conflict (evento_id, data_ocorrencia, aba) do nothing;
  else
    delete from public.ocorrencias_nao_contabilizadas
    where evento_id = p_evento_id and data_ocorrencia = p_data_ocorrencia and aba = p_aba;
  end if;
end;
$func$;

select 'ocorrencias_nao_contabilizadas criada, agora separada por aba.' as status;
