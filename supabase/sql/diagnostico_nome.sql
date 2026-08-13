-- Diagnostico: por que "Leonardo Robert Sant'ana Campos" (extrato) nao
-- casa com o cadastro. So leitura, nao muda nada no banco.

-- 1) A funcao acha a pessoa com esse nome exato (testando direto)?
select tentar_casar_transacao('Leonardo Robert Sant''ana Campos') as resultado_funcao;

-- 2) Como o cadastro esta salvo, em bytes -- pra flagrar espaco
--    duplicado, espaco nao-quebravel, ou qualquer caractere invisivel.
select
  id,
  nome,
  length(nome) as tamanho,
  encode(convert_to(nome, 'UTF8'), 'hex') as nome_em_hex,
  unaccent(lower(nome)) as normalizado
from profiles
where nome ilike '%leonardo%robert%campos%';

-- 3) O mesmo em hex pro texto do extrato, pra comparar lado a lado
--    com o resultado da consulta 2.
select encode(convert_to('Leonardo Robert Sant''ana Campos', 'UTF8'), 'hex') as extrato_em_hex;
