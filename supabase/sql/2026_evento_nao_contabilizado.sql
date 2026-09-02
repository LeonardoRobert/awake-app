-- Nas abas Awake e Shallom do gestao.html, "Apagar" virou "Não
-- contabilizado" -- o evento continua aparecendo na lista, so' sai da
-- contagem/media do dashboard. Reaproveita a tabela
-- contagem_manual_eventos (ja existe uma linha por evento+data quando
-- a aba Shallom tem contagem; agora tambem serve pra guardar essa
-- marcacao na aba Awake, mesmo sem contagem manual nenhuma).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

alter table public.contagem_manual_eventos
  add column if not exists nao_contabilizado boolean not null default false;

create or replace function public.definir_nao_contabilizado_evento(
  p_evento_id uuid,
  p_data_ocorrencia date,
  p_nao_contabilizado boolean
)
returns void
language plpgsql security definer set search_path = public
as $func$
begin
  if not is_admin() then
    raise exception 'Só admin pode marcar um evento como não contabilizado.';
  end if;

  insert into public.contagem_manual_eventos (evento_id, data_ocorrencia, contagem, nao_contabilizado, atualizado_por)
  values (p_evento_id, p_data_ocorrencia, 0, p_nao_contabilizado, auth.uid())
  on conflict (evento_id, data_ocorrencia)
  do update set
    nao_contabilizado = p_nao_contabilizado,
    atualizado_por = auth.uid(),
    atualizado_em = now();
end;
$func$;

select 'nao_contabilizado adicionado.' as status;
