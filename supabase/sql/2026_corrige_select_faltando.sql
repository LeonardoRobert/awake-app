-- Bug achado pelo robo de teste: pedidos_oracao, testemunhos e
-- visitantes_primeira_vez ficaram SO com a policy restritiva
-- "ocultar_teste" (2026_esconder_conta_teste.sql), sem nenhuma policy
-- PERMISSIVA de select por baixo. Restritiva sozinha, sem permissiva
-- pra combinar, significa "ninguem ve nada" -- por isso o proprio
-- envio (que pede a linha de volta com .select()) batia em "new row
-- violates row-level security policy", e a Caixa de Entrada / tela de
-- Visitantes do admin provavelmente tambem estavam quebradas.
--
-- As outras 6 tabelas que 2026_esconder_conta_teste.sql mexeu
-- (contribuicoes, escalas_servico, escala_servico_posicoes, eventos,
-- profile_ministerios, profiles) ja tinham a permissiva certa -- so
-- essas 3 ficaram orfas. Mesmo padrao usado em contribuicoes_select:
-- dono da linha ve a propria, admin ve tudo.
drop policy if exists "pedidos_oracao_select" on public.pedidos_oracao;
create policy "pedidos_oracao_select" on public.pedidos_oracao
  for select using (profile_id = auth.uid() or is_admin());

drop policy if exists "testemunhos_select" on public.testemunhos;
create policy "testemunhos_select" on public.testemunhos
  for select using (profile_id = auth.uid() or is_admin());

drop policy if exists "visitantes_pv_select" on public.visitantes_primeira_vez;
create policy "visitantes_pv_select" on public.visitantes_primeira_vez
  for select using (registrado_por = auth.uid() or is_admin());

select 'Policies de SELECT restauradas em pedidos_oracao, testemunhos e visitantes_primeira_vez.' as status;
