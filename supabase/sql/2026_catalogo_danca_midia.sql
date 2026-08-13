-- Dança e Mídia ficaram com o catálogo de funções vazio -- o "Escala
-- mensal" desses dois ministerios nao mostrava NENHUMA coluna pra
-- preencher. Igual ao backvocal do Louvor: essas 10 posicoes generic
-- as ("Integrante 1" a "Integrante 10") so existiam num fallback do
-- Dart usado pelo Excel antigo, nunca foram cadastradas de verdade em
-- escala_servico_funcoes_catalogo, que e a fonte real que a grade
-- (e a escala Semanal) usam hoje.
--
-- Idempotente: so insere "Integrante N" que ainda nao existir pra
-- cada ministerio.

insert into public.escala_servico_funcoes_catalogo (ministerio, funcao, ordem)
select ministerio, 'Integrante ' || i, i
from (values ('danca'), ('midia')) as m(ministerio)
cross join generate_series(1, 10) as i
where not exists (
  select 1 from public.escala_servico_funcoes_catalogo c
  where c.ministerio = m.ministerio and c.funcao = 'Integrante ' || i
);

-- Confira o resultado:
select ministerio, funcao, ordem from public.escala_servico_funcoes_catalogo
where ministerio in ('danca', 'midia') order by ministerio, ordem;
