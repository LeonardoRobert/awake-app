-- BUG: calcular_categoria() (trigger trg_calcular_categoria) so roda
-- "before insert or update of data_nascimento, estado_civil" -- ou
-- seja, so recalcula quando ALGUEM EDITA esses dois campos. A idade
-- passa sozinha com o tempo (ninguem "edita" a data de nascimento no
-- aniversario), entao a categoria fica travada no valor de quando o
-- cadastro foi feito e NUNCA vira sozinha de Genesis pra Next, nem de
-- Next pra One (se a pessoa casar sem editar estado_civil por engano,
-- esse caso ja e coberto pelo fluxo normal de edicao).
--
-- Correcao: uma funcao com a MESMA logica de calcular_categoria(),
-- rodando 1x por dia via pg_cron pra todo mundo, recalculando so quem
-- mudou de faixa. Nao mexe em data_nascimento/estado_civil (so em
-- categoria), entao nao reaciona a trigger existente -- sem loop.
--
-- categoria e' coluna "text" pura em producao (nao o enum
-- categoria_type que o schema.sql desatualizado sugeria -- confirmado
-- pelo erro "operator does not exist: text = categoria_type" ao rodar
-- a 1a versao deste arquivo), por isso os literais aqui NAO levam cast.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create or replace function public.recalcular_categorias_diario()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.profiles
  set categoria = case
    when estado_civil in ('noivo', 'casado') then 'one'
    when data_nascimento is not null and extract(year from age(data_nascimento)) between 13 and 16
      then 'genesis'
    when data_nascimento is not null and extract(year from age(data_nascimento)) >= 17
      then 'next'
    else null
  end
  where categoria is distinct from (case
    when estado_civil in ('noivo', 'casado') then 'one'
    when data_nascimento is not null and extract(year from age(data_nascimento)) between 13 and 16
      then 'genesis'
    when data_nascimento is not null and extract(year from age(data_nascimento)) >= 17
      then 'next'
    else null
  end);
end;
$$;

-- 6h UTC = 3h da manha em Brasilia (BRT, UTC-3) -- horario morto, sem
-- gente usando o app, igual a logica de escolher madrugada pra jobs
-- em lote.
select cron.schedule(
  'recalcular-categorias-diario',
  '0 6 * * *',
  $$select public.recalcular_categorias_diario();$$
);

-- Roda uma vez agora tambem, pra corrigir quem ja esta com a
-- categoria desatualizada hoje (nao precisa esperar o cron de amanha).
select public.recalcular_categorias_diario();

select 'recalcular_categorias_diario() criada e agendada 1x/dia; categorias existentes ja corrigidas.' as status;
