-- testes_automatizados_execucoes tem RLS ativada (2026_robo_resultados.sql)
-- mas ZERO policies em producao -- confirmado via pg_policies retornando
-- "Success. No rows returned". Isso bloqueia geral, ate admin, sem erro
-- nenhum (a aba "Status" no gestao.html so' via lista vazia, sem
-- excecao no console). O robo grava com a chave de servico (ignora
-- RLS), entao os dados sempre estiveram la' -- so' a leitura que nunca
-- funcionou de verdade.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop policy if exists "testes_automatizados_execucoes_select" on public.testes_automatizados_execucoes;
create policy "testes_automatizados_execucoes_select" on public.testes_automatizados_execucoes
  for select using (is_admin() or is_admin_financeiro());

select 'SELECT restaurado em testes_automatizados_execucoes.' as status;
