-- Unificar admin/admin_financeiro na navegacao (gestao.html) e no app
-- nao mudou as RLS policies de contribuicoes -- elas continuavam
-- checando is_admin_financeiro() especificamente, entao um Admin
-- comum tentando lancar pagamento batia em "new row violates
-- row-level security policy for table contribuicoes".
--
-- Troca as 4 policies pra usar is_admin() (ja cobre os dois papeis)
-- em vez de is_admin_financeiro(). Nao mexe em contribuicoes_ocultar_
-- teste, que nao usa is_admin_financeiro().
drop policy if exists "contribuicoes_select" on public.contribuicoes;
create policy "contribuicoes_select" on public.contribuicoes
  for select using (profile_id = auth.uid() or is_admin());

drop policy if exists "contribuicoes_insert" on public.contribuicoes;
create policy "contribuicoes_insert" on public.contribuicoes
  for insert with check (is_admin());

drop policy if exists "contribuicoes_update" on public.contribuicoes;
create policy "contribuicoes_update" on public.contribuicoes
  for update using (is_admin());

drop policy if exists "contribuicoes_delete" on public.contribuicoes;
create policy "contribuicoes_delete" on public.contribuicoes
  for delete using (is_admin());

select 'Policies de contribuicoes agora aceitam qualquer admin, nao so admin_financeiro.' as status;
