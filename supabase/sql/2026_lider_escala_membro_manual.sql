-- Permite que lider do Awake (ou admin) escale outra pessoa numa
-- ocorrencia de escala Awake, mesmo que ela nao tenha se inscrito
-- sozinha (ex: lider sabe que fulano vai servir, mas fulano esqueceu
-- de se inscrever pelo app).
--
-- Espelha exatamente as mesmas checagens de inscrever_em_escala()
-- (vaga lotada, horario sobreposto, limite de 2 domingos no mes) --
-- so muda QUEM esta sendo inscrito (p_user_id em vez de auth.uid()) e
-- exige que quem chama seja lider do Awake ou admin.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create or replace function public.inscrever_membro_como_lider(
  p_user_id uuid,
  p_escala_id uuid,
  p_data_ocorrencia date
)
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
  if not (is_admin() or is_lider_ministerio('awake')) then
    raise exception 'Só líder do Awake ou admin pode escalar outra pessoa.';
  end if;

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

  if exists (
    select 1
    from public.inscricoes i
    join public.escalas e on e.id = i.escala_id
    where i.user_id = p_user_id
      and i.data_ocorrencia = p_data_ocorrencia
      and i.status in ('inscrito', 'check_in_feito')
      and i.escala_id <> p_escala_id
      and (e.horario_inicio, e.horario_fim) overlaps (v_horario_inicio, v_horario_fim)
  ) then
    raise exception 'Essa pessoa ja esta inscrita em outra escala nesse mesmo horario';
  end if;

  if extract(dow from p_data_ocorrencia) = 0 then
    select count(*) into v_domingos_no_mes
    from public.inscricoes i
    where i.user_id = p_user_id
      and i.status in ('inscrito', 'check_in_feito')
      and extract(dow from i.data_ocorrencia) = 0
      and date_trunc('month', i.data_ocorrencia) = date_trunc('month', p_data_ocorrencia);

    if v_domingos_no_mes >= 2 then
      raise exception 'Essa pessoa ja atingiu o limite_domingos deste mes (maximo de 2)';
    end if;
  end if;

  insert into public.inscricoes (escala_id, data_ocorrencia, user_id)
  values (p_escala_id, p_data_ocorrencia, p_user_id)
  returning id into v_nova_inscricao_id;

  return v_nova_inscricao_id;
end;
$$;

select 'inscrever_membro_como_lider() criada.' as status;
