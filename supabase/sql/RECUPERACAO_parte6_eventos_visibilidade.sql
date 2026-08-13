-- Corrige eventos_select pra visibilidade por publico de verdade, em
-- vez do "qualquer logado ve tudo" que deixei na reconstrucao. Espelha
-- exatamente a logica de audiencia_evento(escopo) (usada hoje pra
-- notificacao, sobreviveu ao incidente intacta):
--   igreja            -> todo mundo
--   homens/mulheres/awake/danca/diaconos/louvor/midia/multimidia/
--   teatro/coral       -> so quem tem vinculo em profile_ministerios
--                         com esse ministerio (qualquer papel)
--   casais            -> so quem tem estado_civil = 'casado'
--   lideranca         -> so quem e lider de algum ministerio
--   criancas / embaixadores_mensageiras -> audiencia_evento() nao
--   cobre esses dois (retorna lista vazia) porque a visibilidade e
--   filtrada no APP (inicio_shallom_screen.dart: mostra a secao de
--   Criancas so se a pessoa tem filho ate 12 anos cadastrado) -- ou
--   seja, o banco sempre devolve a linha, quem decide mostrar ou nao e
--   a tela. Mantido assim aqui (visivel pra qualquer logado).
drop policy if exists "eventos_select" on public.eventos;
create policy "eventos_select" on public.eventos
  for select using (
    is_admin()
    or escopo = 'igreja'
    or escopo in ('criancas', 'embaixadores_mensageiras')
    or (
      escopo in ('homens', 'mulheres', 'awake', 'danca', 'diaconos', 'louvor', 'midia', 'multimidia', 'teatro', 'coral')
      and exists (
        select 1 from public.profile_ministerios pm
        where pm.profile_id = auth.uid() and pm.ministerio = eventos.escopo
      )
    )
    or (
      escopo = 'casais'
      and exists (select 1 from public.profiles p where p.id = auth.uid() and p.estado_civil = 'casado')
    )
    or (
      escopo = 'lideranca'
      and exists (select 1 from public.profile_ministerios pm where pm.profile_id = auth.uid() and pm.papel = 'lider')
    )
  );

select 'Visibilidade de eventos por publico corrigida.' as status;
