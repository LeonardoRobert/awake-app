-- Troca os postos genericos "Integrante 1".."Integrante 10" de Midia
-- pelos postos de verdade. So mexe no CATALOGO (o que aparece pra
-- escolher ao montar uma escala NOVA) -- escalas ja criadas antes
-- continuam com o nome antigo salvo nelas mesmas (escala_servico_
-- posicoes guarda o texto direto, nao referencia o catalogo).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

delete from public.escala_servico_funcoes_catalogo where ministerio = 'midia';

insert into public.escala_servico_funcoes_catalogo (ministerio, funcao, ordem) values
  ('midia', 'Fotografia do louvor', 1),
  ('midia', 'Fotografia da palavra', 2),
  ('midia', 'Treinamento', 3),
  ('midia', 'Reels', 4);

select ministerio, funcao, ordem from public.escala_servico_funcoes_catalogo
where ministerio = 'midia' order by ordem;
