-- Achado numa revisao geral (nao e regressao do incidente -- ja estava
-- assim antes): excluir_ocorrencia_evento() usava is_lider_ou_admin(),
-- uma funcao "morta" (papel='lider' nao existe mais como papel global,
-- so admin passava nessa checagem). Troca pra is_lider_ministerio(),
-- checando o escopo do proprio evento -- lider do ministerio
-- correspondente ja pode gerenciar o evento (mesma regra usada em
-- eventos_insert/update/delete).
create or replace function public.excluir_ocorrencia_evento(p_evento_id uuid, p_data date)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_escopo text;
begin
  select escopo into v_escopo from public.eventos where id = p_evento_id;
  if v_escopo is null then
    raise exception 'Evento nao encontrado';
  end if;

  if not public.is_lider_ministerio(v_escopo) then
    raise exception 'Sem permissao para excluir essa ocorrencia';
  end if;

  update public.eventos
  set excecoes = array_append(coalesce(excecoes, '{}'), p_data)
  where id = p_evento_id
    and not (p_data = any(coalesce(excecoes, '{}')));

  delete from public.presencas_eventos
  where evento_id = p_evento_id and data_ocorrencia = p_data;
end;
$function$;

select 'excluir_ocorrencia_evento corrigida pra permitir lider do ministerio.' as status;
