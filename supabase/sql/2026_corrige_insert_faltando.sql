-- 3 bugs de producao achados pelo robo de teste (Fase 2 e 1):
--
-- 1) eventos_insert/update/delete estavam travados em is_admin() --
--    LIDER NENHUM, de NENHUM ministerio, conseguia criar/editar/apagar
--    evento. is_lider_ministerio() existe e esta correta (ja inclui
--    is_admin() por dentro), so a policy nunca foi atualizada pra
--    usar ela (ou foi revertida em algum momento do incidente).
--
-- 2) treinamentos so tinha policy de SELECT -- ninguem, nem admin,
--    conseguia criar/editar/apagar treinamento.
--
-- 3) filhos nao tinha NENHUMA policy -- ninguem conseguia
--    cadastrar/ver/editar/apagar filho.
drop policy if exists "eventos_insert" on public.eventos;
create policy "eventos_insert" on public.eventos
  for insert with check (is_lider_ministerio(escopo));

drop policy if exists "eventos_update" on public.eventos;
create policy "eventos_update" on public.eventos
  for update using (is_lider_ministerio(escopo));

drop policy if exists "eventos_delete" on public.eventos;
create policy "eventos_delete" on public.eventos
  for delete using (is_lider_ministerio(escopo));

drop policy if exists "treinamentos_insert" on public.treinamentos;
create policy "treinamentos_insert" on public.treinamentos
  for insert with check (is_admin());

drop policy if exists "treinamentos_update" on public.treinamentos;
create policy "treinamentos_update" on public.treinamentos
  for update using (is_admin());

drop policy if exists "treinamentos_delete" on public.treinamentos;
create policy "treinamentos_delete" on public.treinamentos
  for delete using (is_admin());

drop policy if exists "filhos_select" on public.filhos;
create policy "filhos_select" on public.filhos
  for select using (responsavel_id = auth.uid() or is_admin());

drop policy if exists "filhos_insert" on public.filhos;
create policy "filhos_insert" on public.filhos
  for insert with check (responsavel_id = auth.uid());

drop policy if exists "filhos_update" on public.filhos;
create policy "filhos_update" on public.filhos
  for update using (responsavel_id = auth.uid());

drop policy if exists "filhos_delete" on public.filhos;
create policy "filhos_delete" on public.filhos
  for delete using (responsavel_id = auth.uid());

select 'eventos (lider), treinamentos e filhos: policies de escrita restauradas.' as status;
