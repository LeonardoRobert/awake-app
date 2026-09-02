-- Duas coisas novas, pro gestao.html (abas Awake e Shallom):
--
-- 1) Tabela contagem_manual_eventos -- pros eventos "gerais" (EBD,
--    Culto de Celebracao, Culto da Familia) onde nao da pra escanear
--    QR Code de todo mundo -- o admin so' aperta +/- no app pra ir
--    contando. Uma linha por (evento_id, data_ocorrencia).
--
-- 2) admin_adicionar_checkin_evento() -- na aba Awake, "Editar" um
--    evento deixa o admin marcar manualmente quem foi (check-in
--    retroativo), sem precisar ter escaneado o QR Code na hora.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create table if not exists public.contagem_manual_eventos (
  id uuid primary key default gen_random_uuid(),
  evento_id uuid not null references public.eventos(id) on delete cascade,
  data_ocorrencia date not null,
  contagem int not null default 0,
  atualizado_por uuid references public.profiles(id),
  atualizado_em timestamptz not null default now(),
  unique (evento_id, data_ocorrencia)
);

alter table public.contagem_manual_eventos enable row level security;

drop policy if exists "contagem_manual_eventos_select" on public.contagem_manual_eventos;
create policy "contagem_manual_eventos_select" on public.contagem_manual_eventos
  for select using (is_admin());

-- Ajuste relativo (+1/-1) -- usado pelo botao +/- no app. Atomico (o
-- "greatest" acontece dentro do UPSERT, sem ler-e-escrever em dois
-- passos), pra nao perder incremento se dois admins apertarem quase
-- ao mesmo tempo. Nunca deixa a contagem ficar negativa.
create or replace function public.ajustar_contagem_evento(
  p_evento_id uuid,
  p_data_ocorrencia date,
  p_delta int
)
returns int
language plpgsql security definer set search_path = public
as $func$
declare
  v_nova_contagem int;
begin
  if not is_admin() then
    raise exception 'Só admin pode ajustar a contagem de presença.';
  end if;

  insert into public.contagem_manual_eventos (evento_id, data_ocorrencia, contagem, atualizado_por)
  values (p_evento_id, p_data_ocorrencia, greatest(0, p_delta), auth.uid())
  on conflict (evento_id, data_ocorrencia)
  do update set
    contagem = greatest(0, contagem_manual_eventos.contagem + p_delta),
    atualizado_por = auth.uid(),
    atualizado_em = now()
  returning contagem into v_nova_contagem;

  return v_nova_contagem;
end;
$func$;

-- Ajuste absoluto -- so' usado pelo "Editar" da aba Shallom no
-- gestao.html, pra corrigir a contagem direto (digitar o numero certo)
-- em vez de clicar +/- varias vezes.
create or replace function public.definir_contagem_evento(
  p_evento_id uuid,
  p_data_ocorrencia date,
  p_valor int
)
returns int
language plpgsql security definer set search_path = public
as $func$
begin
  if not is_admin() then
    raise exception 'Só admin pode ajustar a contagem de presença.';
  end if;
  if p_valor < 0 then
    raise exception 'A contagem não pode ser negativa.';
  end if;

  insert into public.contagem_manual_eventos (evento_id, data_ocorrencia, contagem, atualizado_por)
  values (p_evento_id, p_data_ocorrencia, p_valor, auth.uid())
  on conflict (evento_id, data_ocorrencia)
  do update set contagem = p_valor, atualizado_por = auth.uid(), atualizado_em = now();

  return p_valor;
end;
$func$;

-- Check-in retroativo (aba Awake, botao "Editar") -- admin marca que
-- alguem foi, sem precisar ter escaneado o QR Code dela na hora.
create or replace function public.admin_adicionar_checkin_evento(
  p_user_id uuid,
  p_evento_id uuid,
  p_data_ocorrencia date
)
returns void
language plpgsql security definer set search_path = public
as $func$
begin
  if not is_admin() then
    raise exception 'Só admin pode adicionar check-in retroativo.';
  end if;

  if exists (
    select 1 from public.presencas_eventos
    where evento_id = p_evento_id and user_id = p_user_id and data_ocorrencia = p_data_ocorrencia
  ) then
    return; -- ja tinha check-in, nao duplica
  end if;

  insert into public.presencas_eventos (evento_id, user_id, data_ocorrencia, feito_por)
  values (p_evento_id, p_user_id, p_data_ocorrencia, auth.uid());
end;
$func$;

select 'contagem_manual_eventos + funcoes criadas.' as status;
