-- "Visitantes -- Primeira Vez" (com o copiar-e-colar pro WhatsApp) fica
-- disponivel pra TODOS os lideres do Awake agora, nao so' admin --
-- assim como o Dashboard ja e' visivel pra qualquer lider. visitantes_
-- pv_select hoje so libera quem registrou o proprio visitante ou
-- admin -- adiciona is_lider_ministerio('awake'). O UPDATE (marcar
-- como lido, botao que ja existe na mesma tela) tambem precisa disso,
-- senao o botao aparece pro lider mas falha em silencio.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop policy if exists "visitantes_pv_select" on public.visitantes_primeira_vez;
create policy "visitantes_pv_select" on public.visitantes_primeira_vez
  for select using (
    registrado_por = auth.uid()
    or is_admin()
    or is_lider_ministerio('awake')
  );

drop policy if exists "visitantes_pv_update" on public.visitantes_primeira_vez;
create policy "visitantes_pv_update" on public.visitantes_primeira_vez
  for update using (is_admin() or is_lider_ministerio('awake'));

select 'visitantes_primeira_vez agora libera lider do Awake tambem.' as status;
