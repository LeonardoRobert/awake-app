-- Agrupa as linhas de uma mesma importacao de extrato (mesmo clique em
-- "Confirmar tudo"), pra dar pra apagar uma importacao inteira de uma
-- vez se foi importada errada -- sem precisar achar linha por linha.
-- So preenchido pra linhas vindas de extrato; lancamento manual e
-- lancamento antigo continuam com isso nulo. Nao precisa de policy
-- nova -- contribuicoes_delete ja libera is_admin_financeiro() pra
-- apagar qualquer linha, sem restricao por lote.
alter table public.contribuicoes
  add column if not exists lote_importacao_id uuid;
