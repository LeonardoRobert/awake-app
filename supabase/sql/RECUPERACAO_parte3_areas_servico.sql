-- Corrige areas_servico -- o incidente original zerou essa tabela e
-- ela ficou com o seed padrao do schema.sql antigo (Louvor, Recepcao,
-- Midia, Intercessao), que estava ERRADO. Nomes reais confirmados
-- pelo Leo: "Recepção/Primeira Vez", "Doce como Mel", "Outro".
--
-- truncate + cascade apaga as 4 linhas erradas (e qualquer linha de
-- escalas que apontasse pra elas -- seguro hoje porque escalas tem 0
-- linhas, confirmado no diagnostico anterior).
truncate table public.areas_servico cascade;

insert into public.areas_servico (nome) values
  ('Recepção/Primeira Vez'),
  ('Doce como Mel'),
  ('Outro');
