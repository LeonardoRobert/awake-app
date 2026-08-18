-- Atualiza a ordem dos postos de Midia -- adiciona "Stories" entre
-- "Fotografia da palavra" e "Treinamento". So mexe no CATALOGO (o que
-- aparece pra escolher ao montar uma escala NOVA) -- escalas ja
-- criadas antes continuam com o nome antigo salvo nelas mesmas
-- (escala_servico_posicoes guarda o texto direto, nao referencia o
-- catalogo).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

delete from public.escala_servico_funcoes_catalogo where ministerio = 'midia';

insert into public.escala_servico_funcoes_catalogo (ministerio, funcao, ordem) values
  ('midia', 'Fotografia do louvor', 1),
  ('midia', 'Fotografia da palavra', 2),
  ('midia', 'Stories', 3),
  ('midia', 'Treinamento', 4),
  ('midia', 'Reels', 5);

select ministerio, funcao, ordem from public.escala_servico_funcoes_catalogo
where ministerio = 'midia' order by ordem;
