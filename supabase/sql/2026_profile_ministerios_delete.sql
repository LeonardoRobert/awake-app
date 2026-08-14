-- profile_ministerios nunca teve policy de DELETE -- so dava pra
-- alternar papel membro<->lider (update) ou adicionar (insert), nunca
-- remover o vinculo inteiro (ex: a pessoa saiu do Coral). Mesmo padrao
-- de is_admin()/is_admin_financeiro() ja usado em
-- 2026_admin_usuarios_rls.sql pro update dessa tabela.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop policy if exists "profile_ministerios_delete" on public.profile_ministerios;
create policy "profile_ministerios_delete" on public.profile_ministerios
  for delete using (
    is_admin() or is_admin_financeiro()
  );

select 'Policy de delete em profile_ministerios criada.' as status;
