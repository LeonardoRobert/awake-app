-- presencas_eventos tinha RLS ativado mas ZERO policies -- sem
-- nenhuma policy permissiva, RLS nega leitura pra todo mundo por
-- padrao (inclusive admin). Por isso a aba Awake do gestao.html
-- mostrava "0 check-ins" mesmo com check-ins reais gravados: a
-- ESCRITA acontece via check_in_evento() (SECURITY DEFINER, ignora
-- RLS), mas a LEITURA direta que o gestao.html faz batia na parede.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop policy if exists "presencas_eventos_select" on public.presencas_eventos;
create policy "presencas_eventos_select" on public.presencas_eventos
  for select using (is_admin());

select 'presencas_eventos_select criada.' as status;
