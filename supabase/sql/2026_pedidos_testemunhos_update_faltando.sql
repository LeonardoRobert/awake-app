-- pedidos_oracao/testemunhos NUNCA tiveram policy de UPDATE (so
-- select/insert/delete) -- o botao "Marcar como lido" em
-- admin_mensagens_screen.dart sempre rodou o UPDATE sem erro nenhum
-- (Postgres nao avisa quando o USING de uma policy inexistente barra 0
-- linhas em silencio), mas nunca persistia de verdade. Achado pelo
-- robo de teste, que confere lendo de volta em vez de so' confiar que
-- a chamada nao lançou excecao.

drop policy if exists "pedidos_oracao_update" on public.pedidos_oracao;
create policy "pedidos_oracao_update" on public.pedidos_oracao
  for update using (is_admin());

drop policy if exists "testemunhos_update" on public.testemunhos;
create policy "testemunhos_update" on public.testemunhos
  for update using (is_admin());

select 'UPDATE restaurado em pedidos_oracao e testemunhos.' as status;
