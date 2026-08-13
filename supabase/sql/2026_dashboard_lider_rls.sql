-- Dashboards de lider (Homens/Mulheres/Awake e Areas de Servico) e o
-- dashboard combinado do Admin precisam ler vinculo de ministerio de
-- gente de QUALQUER grupo (nao so o que a pessoa lidera), pra calcular
-- coisas como "% dos meus membros que tambem servem em Louvor".
--
-- Hoje profile_ministerios_select so libera a propria linha ou
-- admin/admin financeiro -- por isso dashboard_ministerio_screen.dart
-- provavelmente ja mostra numero errado de membros pra lider comum
-- (so enxerga a propria linha).
--
-- CORRECAO (v2): a primeira versao desse arquivo causou
-- "infinite recursion detected in policy for relation
-- profile_ministerios" -- a policy consultava a propria tabela
-- profile_ministerios de dentro dela mesma, o que o Postgres nao
-- permite (reaplica a policy recursivamente). O jeito certo, mesmo
-- padrao ja usado por is_admin()/is_lider_ministerio(), e colocar
-- essa consulta dentro de uma funcao SECURITY DEFINER -- ela roda com
-- privilegio elevado e NAO reaplica RLS na consulta interna.

create or replace function public.is_lider_de_algum_ministerio()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profile_ministerios
    where profile_id = auth.uid() and papel = 'lider'
  );
$$;

drop policy if exists "profile_ministerios_select" on public.profile_ministerios;
create policy "profile_ministerios_select" on public.profile_ministerios
  for select using (
    profile_id = auth.uid()
    or is_admin()
    or is_admin_financeiro()
    or is_lider_de_algum_ministerio()
  );
