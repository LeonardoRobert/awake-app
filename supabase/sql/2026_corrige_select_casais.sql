-- Mesmo padrao dos outros bugs de hoje: escala_servico_casais tinha
-- insert/update/delete usando is_lider_ministerio(ministerio) certo,
-- mas NENHUMA policy de SELECT -- o upsert do robo (mesmo sem
-- .select() explicito) esbarrava em "violates row-level security
-- policy" porque o INSERT ... ON CONFLICT DO UPDATE do upsert precisa
-- de visibilidade SELECT sobre a linha.
drop policy if exists "escala_servico_casais_select" on public.escala_servico_casais;
create policy "escala_servico_casais_select" on public.escala_servico_casais
  for select using (is_lider_ministerio(ministerio));

select 'SELECT restaurado em escala_servico_casais.' as status;
