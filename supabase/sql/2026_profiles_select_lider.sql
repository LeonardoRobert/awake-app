-- BUG: profiles_select so liberava a propria linha, is_admin() ou
-- is_admin_financeiro() -- NUNCA incluiu lider nenhum (nem de
-- ministerio de servico, nem de area do Awake). Por isso
-- listSignupsForOccurrence() (Escala Awake) sempre devolvia
-- profiles=null no join, e a tela do lider caia no fallback "Membro"
-- pra todo mundo -- nao tem como saber o nome de quem se inscreveu sem
-- poder ler profiles de outra pessoa.
--
-- Mesmo padrao ja usado em profile_ministerios_select/
-- escala_servico_casais_select -- adiciona is_lider_de_algum_
-- ministerio() como mais uma condicao permissiva.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles
  for select using (
    id = auth.uid()
    or is_admin()
    or is_admin_financeiro()
    or is_lider_de_algum_ministerio()
  );

select 'profiles_select agora libera lideres tambem.' as status;
