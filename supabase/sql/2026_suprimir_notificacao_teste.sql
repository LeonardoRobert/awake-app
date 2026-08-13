-- Robo de teste: garante que nenhuma acao de conta de teste dispara
-- push de verdade. Duas camadas, porque sao dois problemas diferentes:
--
-- 1) notificar() -- filtra os DESTINATARIOS: uma conta de teste nunca
--    deveria RECEBER push de verdade (ex: robo escala a propria conta
--    de teste, isso nao pode virar notificacao real). Como as 3
--    triggers passam por essa funcao central, um filtro aqui ja
--    resolve pra todas de uma vez.
--
-- 2) trigger_notificar_admin_novo() e trigger_notificar_novo_evento()
--    -- filtram a ORIGEM: um pedido de oracao/testemunho/visitante/
--    evento CRIADO por conta de teste nao pode notificar os admins DE
--    VERDADE (isso o filtro de destinatario da camada 1 nao resolve,
--    porque quem recebe e um admin real, so quem gerou que e falso).
--
-- trigger_notificar_escalado() NAO precisa mudar: o robo so vai
-- escalar contas de teste, e a camada 1 (filtro de destinatario) ja
-- garante que ninguem real recebe push nesse caso.
--
-- IMPORTANTE pra quando o robo for escrito: pedidos_oracao/testemunhos
-- tem a opcao de "anonimo" (profile_id fica null nesse caso) -- o robo
-- PRECISA enviar os testes dele com profile_id preenchido (nao
-- anonimo), senao essa checagem nao tem como saber que e teste.

create or replace function public.notificar(p_profile_ids uuid[], p_titulo text, p_mensagem text, p_dados jsonb DEFAULT '{}'::jsonb)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_ids_reais uuid[];
begin
  if p_profile_ids is null or array_length(p_profile_ids, 1) is null then
    return;
  end if;

  -- Nunca manda push de verdade pra conta de teste.
  select array_agg(id) into v_ids_reais
  from profiles
  where id = any(p_profile_ids) and coalesce(eh_conta_teste, false) = false;

  if v_ids_reais is null or array_length(v_ids_reais, 1) is null then
    return;
  end if;

  perform net.http_post(
    url := 'https://eetethnvupitlquhdjkx.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVldGV0aG52dXBpdGxxdWhkamt4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1NDI4MjksImV4cCI6MjEwMTExODgyOX0.QL1dNFxoRuHJwf_pwAzFou34oA0cSAkUguND0l9b4z8'
    ),
    body := jsonb_build_object(
      'profileIds', to_jsonb(v_ids_reais),
      'titulo', p_titulo,
      'mensagem', p_mensagem,
      'dados', p_dados
    )
  );
end;
$function$;

create or replace function public.trigger_notificar_admin_novo()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_admin_ids uuid[];
  v_titulo text;
  v_mensagem text;
  v_origem uuid;
  v_eh_teste boolean;
begin
  -- Quem gerou essa linha varia por tabela.
  if tg_table_name in ('pedidos_oracao', 'testemunhos') then
    v_origem := new.profile_id; -- null quando for anonimo (nao da pra saber, entao nao suprime)
  elsif tg_table_name = 'visitantes_primeira_vez' then
    v_origem := new.registrado_por;
  end if;

  if v_origem is not null then
    select coalesce(eh_conta_teste, false) into v_eh_teste from profiles where id = v_origem;
    if v_eh_teste then
      return new;
    end if;
  end if;

  select array_agg(id) into v_admin_ids from profiles where papel in ('admin', 'admin_financeiro');

  if tg_table_name = 'pedidos_oracao' then
    v_titulo := 'Novo pedido de oração';
    v_mensagem := 'Alguém enviou um novo pedido de oração.';
  elsif tg_table_name = 'testemunhos' then
    v_titulo := 'Novo testemunho';
    v_mensagem := 'Alguém compartilhou um novo testemunho.';
  elsif tg_table_name = 'visitantes_primeira_vez' then
    v_titulo := 'Novo visitante registrado';
    v_mensagem := 'Um visitante novo foi registrado pela equipe da Primeira Vez.';
  else
    v_titulo := 'Nova mensagem';
    v_mensagem := 'Chegou algo novo pra você conferir.';
  end if;

  perform public.notificar(
    v_admin_ids, v_titulo, v_mensagem,
    jsonb_build_object('tipo', tg_table_name, 'id', new.id)
  );
  return new;
end;
$function$;

create or replace function public.trigger_notificar_novo_evento()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_ids uuid[];
  v_eh_teste boolean;
begin
  if new.criado_por is not null then
    select coalesce(eh_conta_teste, false) into v_eh_teste from profiles where id = new.criado_por;
    if v_eh_teste then
      return new;
    end if;
  end if;

  v_ids := public.audiencia_evento(new.escopo::text);
  perform public.notificar(
    v_ids,
    'Novo evento: ' || new.titulo,
    to_char(new.data_inicio, 'DD/MM') || ' — confira os detalhes no app.',
    jsonb_build_object('tipo', 'novo_evento', 'evento_id', new.id)
  );
  return new;
end;
$function$;
