-- escalas_servico nunca teve uma policy PERMISSIVA de select -- so a
-- restritiva de esconder conta de teste, que sozinha nao concede
-- leitura nenhuma (restritiva so tira, nunca da acesso). Isso sempre
-- bloqueou silenciosamente qualquer coisa que dependa de ler de volta
-- a linha (ex: .select('id') depois de criar uma escala nova), com o
-- Postgres mostrando o mesmo erro generico de "violates RLS policy"
-- tanto pra insert bloqueado quanto pra select-apos-insert bloqueado.
create policy "escalas_servico_select" on public.escalas_servico
  for select using (auth.uid() is not null);
