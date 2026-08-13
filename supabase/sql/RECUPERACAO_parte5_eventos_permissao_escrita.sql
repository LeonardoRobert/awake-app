-- Corrige eventos_insert/update/delete: eu tinha deixado só is_admin(),
-- mas lider de ministerio tambem pode gerenciar evento do proprio
-- escopo (ex: lider de Homens cria evento de Homens). is_lider_ministerio()
-- ja inclui is_admin() OR por dentro, entao cobre os dois casos.
--
-- Escopos como 'igreja'/'lideranca'/'casais'/'embaixadores_mensageiras'
-- nao batem com nenhum ministerio em profile_ministerios -- pra esses,
-- is_lider_ministerio(escopo) cai automaticamente so no is_admin(),
-- que e o comportamento certo (so admin mexe neles).
drop policy if exists "eventos_insert" on public.eventos;
create policy "eventos_insert" on public.eventos
  for insert with check (is_lider_ministerio(escopo));

drop policy if exists "eventos_update" on public.eventos;
create policy "eventos_update" on public.eventos
  for update using (is_lider_ministerio(escopo));

drop policy if exists "eventos_delete" on public.eventos;
create policy "eventos_delete" on public.eventos
  for delete using (is_lider_ministerio(escopo));

select 'Permissao de criar/editar evento por lider de ministerio corrigida.' as status;
