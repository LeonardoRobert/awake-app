-- BUG: profile_ministerios_select nunca incluiu lider nenhum (so
-- profile_id = auth.uid(), is_admin(), is_admin_financeiro()) --
-- dashboard_ministerio_screen.dart busca TODO MUNDO do ministerio com
-- "select ... where ministerio = X", mas um lider nao-admin so
-- enxergava a PROPRIA linha (o resto ficava filtrado pela RLS em
-- silencio) -- por isso o dashboard so mostrava os dados dele mesmo.
--
-- Usa is_lider_ministerio(ministerio) (verifica contra o ministerio DA
-- LINHA sendo lida, nao "lider de qualquer ministerio") -- lider do
-- Awake ve o time do Awake, mas nao ganha visibilidade em ministerios
-- que ele nao lidera.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop policy if exists "profile_ministerios_select" on public.profile_ministerios;
create policy "profile_ministerios_select" on public.profile_ministerios
  for select using (
    profile_id = auth.uid()
    or is_admin()
    or is_admin_financeiro()
    or is_lider_ministerio(ministerio)
  );

select 'profile_ministerios_select agora libera lider ver o proprio ministerio inteiro.' as status;
