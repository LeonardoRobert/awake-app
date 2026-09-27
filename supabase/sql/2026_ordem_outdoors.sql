-- Permite reordenar manualmente os banners do slideshow (antes so'
-- dava pra controlar a ordem indiretamente, por criado_em) -- pedido
-- do Leo.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

alter table public.outdoors
  add column if not exists ordem int not null default 0;

-- Backfill unico: os outdoors ja existentes ganham uma ordem inicial
-- que preserva a ordem atual (por criado_em), pra ninguem notar
-- diferenca ate mexer manualmente.
with numerados as (
  select id, row_number() over (order by criado_em asc) as rn
  from public.outdoors
)
update public.outdoors o
set ordem = numerados.rn
from numerados
where numerados.id = o.id;

select 'outdoors.ordem criada e preenchida.' as status;
