-- BUG: inscrever_em_escala() ja checava lotacao e limite de 2 domingos
-- por mes, mas NUNCA checava se a pessoa ja estava inscrita em OUTRA
-- escala com horario sobreposto no mesmo dia -- dava pra se inscrever
-- em duas escalas ao mesmo tempo.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create or replace function public.inscrever_em_escala(p_escala_id uuid, p_data_ocorrencia date)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_vagas int;
  v_horario_inicio time;
  v_horario_fim time;
  v_inscritos int;
  v_domingos_no_mes int;
  v_nova_inscricao_id uuid;
begin
  select vagas, horario_inicio, horario_fim
    into v_vagas, v_horario_inicio, v_horario_fim
  from public.escalas where id = p_escala_id;
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

  -- Impede se inscrever em duas escalas com horario sobreposto no
  -- mesmo dia (ex: uma das 9h-10h e outra das 9h30-10h30).
  if exists (
    select 1
    from public.inscricoes i
    join public.escalas e on e.id = i.escala_id
    where i.user_id = auth.uid()
      and i.data_ocorrencia = p_data_ocorrencia
      and i.status in ('inscrito', 'check_in_feito')
      and i.escala_id <> p_escala_id
      and (e.horario_inicio, e.horario_fim) overlaps (v_horario_inicio, v_horario_fim)
  ) then
    raise exception 'Voce ja esta inscrito(a) em outra escala nesse mesmo horario';
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

select 'inscrever_em_escala() agora impede horario sobreposto.' as status;
