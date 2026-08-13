-- Corrige eventos_select pra tambem respeitar os subgrupos dentro de
-- Awake (publico_alvo=categoria, publico_genero=sexo -- os dois
-- precisam bater junto, nao um ou outro), Coral (so publico_genero) e
-- Casais (publico_casais=grupo_casais, ou 'one' pra quem e casado E
-- categoria='one'). A parte 6 So filtrava por ministerio/escopo, sem
-- entrar nos subgrupos -- por isso casais via todos os grupos e Awake
-- veria todo mundo junto.
drop policy if exists "eventos_select" on public.eventos;
create policy "eventos_select" on public.eventos
  for select using (
    is_admin()
    or escopo = 'igreja'
    or escopo = 'embaixadores_mensageiras' -- ainda sem regra de idade (falta confirmar a faixa) -- visivel pra qualquer logado por enquanto
    or (
      escopo = 'criancas'
      and exists (
        select 1 from public.filhos f
        where f.responsavel_id = auth.uid()
          and extract(year from age(f.data_nascimento)) <= 12
      )
    )
    or (
      escopo = 'awake'
      and exists (select 1 from public.profile_ministerios pm where pm.profile_id = auth.uid() and pm.ministerio = 'awake')
      and (publico_alvo is null or exists (
        select 1 from public.profiles p where p.id = auth.uid() and p.categoria = any(eventos.publico_alvo)
      ))
      and (publico_genero is null or exists (
        select 1 from public.profiles p where p.id = auth.uid() and p.sexo = any(eventos.publico_genero)
      ))
    )
    or (
      escopo = 'coral'
      and exists (select 1 from public.profile_ministerios pm where pm.profile_id = auth.uid() and pm.ministerio = 'coral')
      and (publico_genero is null or exists (
        select 1 from public.profiles p where p.id = auth.uid() and p.sexo = any(eventos.publico_genero)
      ))
    )
    or (
      escopo in ('homens', 'mulheres', 'danca', 'diaconos', 'louvor', 'midia', 'multimidia', 'teatro')
      and exists (select 1 from public.profile_ministerios pm where pm.profile_id = auth.uid() and pm.ministerio = eventos.escopo)
    )
    or (
      escopo = 'casais'
      and exists (select 1 from public.profiles p where p.id = auth.uid() and p.estado_civil = 'casado')
      and (publico_casais is null or exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and (
            (p.categoria = 'one' and 'one' = any(eventos.publico_casais))
            or p.grupo_casais = any(eventos.publico_casais)
          )
      ))
    )
    or (
      escopo = 'lideranca'
      and exists (select 1 from public.profile_ministerios pm where pm.profile_id = auth.uid() and pm.papel = 'lider')
    )
  );

select 'Subgrupos de eventos (Awake, Coral, Casais) corrigidos.' as status;
