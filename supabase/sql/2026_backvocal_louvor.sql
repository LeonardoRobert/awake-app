-- As 5 posicoes de Backing Vocal nunca apareciam pra preencher na
-- escala (nem semanal, nem mensal) porque so existiam numa lista fixa
-- do Dart usada pelo Excel antigo -- nunca foram cadastradas de
-- verdade em escala_servico_funcoes_catalogo, que e a fonte real que
-- tanto a escala Semanal quanto a grade Mensal usam hoje.
--
-- Idempotente: so insere "Backing Vocal N" que ainda nao existir pra
-- louvor, continuando a partir do maior "ordem" ja cadastrado.

insert into public.escala_servico_funcoes_catalogo (ministerio, funcao, ordem)
select 'louvor', nome, base + i
from (
  select coalesce(max(ordem), 0) as base
  from public.escala_servico_funcoes_catalogo
  where ministerio = 'louvor'
) atual
cross join (values (1, 'Backing Vocal 1'), (2, 'Backing Vocal 2'), (3, 'Backing Vocal 3'),
                    (4, 'Backing Vocal 4'), (5, 'Backing Vocal 5')) as bv(i, nome)
where not exists (
  select 1 from public.escala_servico_funcoes_catalogo c
  where c.ministerio = 'louvor' and c.funcao = bv.nome
);

-- Confira o resultado:
select funcao, ordem from public.escala_servico_funcoes_catalogo
where ministerio = 'louvor' order by ordem;
