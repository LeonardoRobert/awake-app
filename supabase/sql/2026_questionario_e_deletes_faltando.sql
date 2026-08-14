-- 1) questionarios_novo_servo NAO EXISTE no banco -- a feature inteira
-- (questionario_model.dart/questionario_service.dart/
-- link_questionario_novo_servo.dart) quebra com "relation does not
-- exist" (nem chega a ser erro de RLS). Cria do zero, no mesmo formato
-- de pedidos_oracao/testemunhos (profile_id + conteudo em jsonb aqui,
-- ja que respostas e um formulario de varias perguntas, nao um texto
-- so).
create table if not exists public.questionarios_novo_servo (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id),
  respostas jsonb not null default '{}'::jsonb,
  lido boolean not null default false,
  criado_em timestamptz not null default now()
);

alter table public.questionarios_novo_servo enable row level security;

drop policy if exists "questionarios_novo_servo_select" on public.questionarios_novo_servo;
create policy "questionarios_novo_servo_select" on public.questionarios_novo_servo
  for select using (profile_id = auth.uid() or is_admin());

drop policy if exists "questionarios_novo_servo_insert" on public.questionarios_novo_servo;
create policy "questionarios_novo_servo_insert" on public.questionarios_novo_servo
  for insert with check (profile_id = auth.uid());

drop policy if exists "questionarios_novo_servo_update" on public.questionarios_novo_servo;
create policy "questionarios_novo_servo_update" on public.questionarios_novo_servo
  for update using (is_admin());

drop policy if exists "questionarios_novo_servo_delete" on public.questionarios_novo_servo;
create policy "questionarios_novo_servo_delete" on public.questionarios_novo_servo
  for delete using (is_admin());

-- 2) pedidos_oracao/testemunhos nunca tiveram policy de DELETE (o
-- botao "Apagar" novo na Caixa de Entrada ia falhar sem isso).
drop policy if exists "pedidos_oracao_delete" on public.pedidos_oracao;
create policy "pedidos_oracao_delete" on public.pedidos_oracao
  for delete using (is_admin());

drop policy if exists "testemunhos_delete" on public.testemunhos;
create policy "testemunhos_delete" on public.testemunhos
  for delete using (is_admin());

-- 3) visitantes_primeira_vez nunca teve UPDATE (marcarComoLido) nem
-- DELETE.
drop policy if exists "visitantes_pv_update" on public.visitantes_primeira_vez;
create policy "visitantes_pv_update" on public.visitantes_primeira_vez
  for update using (is_admin());

drop policy if exists "visitantes_pv_delete" on public.visitantes_primeira_vez;
create policy "visitantes_pv_delete" on public.visitantes_primeira_vez
  for delete using (is_admin());

select 'questionarios_novo_servo criada; deletes/updates faltando restaurados.' as status;
