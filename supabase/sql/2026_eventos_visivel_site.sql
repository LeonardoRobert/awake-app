-- Controle manual de quais eventos aparecem na agenda publica do site
-- (site.html). Antes era so por escopo (igreja/homens/mulheres/awake),
-- o que nao dava pra fazer o que o Leo pediu: mostrar so alguns
-- eventos especificos de cada escopo (ex: "Maes que Oram" e "Aerobica"
-- sim, "Culto das Mulheres" nao; "Comunhao" sim, os GCs nao), e incluir
-- Embaixadores e Mensageiras (escopo que antes nao aparecia no site).
--
-- Default false: nenhum evento aparece no site ate o Leo marcar
-- manualmente "Mostrar no site publico" nele.
alter table public.eventos
  add column if not exists visivel_site_publico boolean not null default false;

-- View publica: agora manda so pelo campo, nao mais por escopo fixo.
create or replace view public.eventos_publicos as
select * from public.eventos where visivel_site_publico = true;

-- Policy publica (anon, usada pelo fetch do site.html) -- mesma logica.
drop policy if exists "eventos_select_publico" on public.eventos;
create policy "eventos_select_publico" on public.eventos
  for select to anon using (visivel_site_publico = true);

select 'Coluna visivel_site_publico criada -- marque manualmente quais eventos aparecem no site.' as status;
