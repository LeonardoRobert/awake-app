-- Fase 5 do plano "Escala Mensal -> Grade editavel": tela de Admin no
-- gestao.html (lista de usuarios + agregados por ministerio/grupo, com
-- acao de promover/remover lider).
--
-- Confirmado via pg_policies que hoje 'profile_ministerios' so deixa
-- is_admin() ler/atualizar dados de OUTRAS pessoas (admin_financeiro so
-- ve as proprias linhas). Como a tela nova precisa ficar visivel E
-- editavel pros dois papeis (Admin e Admin Financeiro), este SQL
-- estende as policies de select/update pra incluir is_admin_financeiro()
-- tambem -- mesmo padrao ja usado em profiles_select_admin_financeiro.
--
-- Nao mexe em insert/delete (a tela so alterna papel membro<->lider em
-- vinculos ja existentes, nunca cria/apaga vinculo de ministerio).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop policy if exists "profile_ministerios_select" on public.profile_ministerios;
create policy "profile_ministerios_select" on public.profile_ministerios
  for select using (
    profile_id = auth.uid() or is_admin() or is_admin_financeiro()
  );

drop policy if exists "profile_ministerios_update" on public.profile_ministerios;
create policy "profile_ministerios_update" on public.profile_ministerios
  for update using (
    is_admin() or is_admin_financeiro()
  );
