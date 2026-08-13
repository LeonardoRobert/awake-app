-- Contribuicoes ganha um "tipo" (dizimo/oferta/outro), separado do
-- meio de pagamento (pix/dinheiro/cartao/...). Ate agora nao existia
-- nenhum jeito de saber, olhando um lancamento, se era dizimo ou
-- oferta -- inclusive a escolha que o proprio membro ja faz ao gerar
-- o codigo Pix (Dizimo x Oferta) nunca era salva em lugar nenhum, so
-- servia pra pre-preencher o valor fixo salvo.
--
-- Nulo = nao especificado (todo lancamento ja existente antes desse
-- campo existir, e qualquer um que ninguem escolher explicitamente).

alter table public.contribuicoes
  add column if not exists tipo text;

alter table public.contribuicoes
  drop constraint if exists contribuicoes_tipo_check;

alter table public.contribuicoes
  add constraint contribuicoes_tipo_check
  check (tipo is null or tipo in ('dizimo', 'oferta', 'outro'));
