-- Corrige o id da area "Recepção/Primeira Vez" pro UUID fixo que a
-- funcao esta_na_escala_primeira_vez() espera -- o insert anterior
-- (parte 3) gerou um id aleatorio novo, que NAO bate com o hardcoded
-- na funcao, entao o botao de Primeira Vez continuaria nunca aparecendo.
update public.areas_servico
set id = '7678a09a-1141-4fcb-833d-0736c91038f0'
where nome = 'Recepção/Primeira Vez';

-- Confere:
select id, nome from public.areas_servico order by nome;
