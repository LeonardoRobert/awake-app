-- Versao consolidada da policy eventos_select -- junta a regra de
-- idade de Embaixadores e Mensageiras (RECUPERACAO_parte8: 9-17 anos,
-- visivel pra quem tem filho nessa faixa OU e adolescente do Awake
-- nessa faixa) com a adicao do Ministerio de Intercessao
-- (2026_intercessao.sql). O 2026_intercessao.sql foi escrito em cima
-- de uma versao ANTERIOR (parte7, sem a regra de idade) -- se ele
-- rodou depois do parte8, reverteu Embaixadores/Mensageiras pra
-- "visivel pra todo mundo" de novo. Esse arquivo aqui vira a versao
-- definitiva daqui pra frente -- pode rodar quantas vezes quiser
-- (drop+create), nao depende de ter rodado parte8 ou o
-- 2026_intercessao.sql antes.
drop policy if exists "eventos_select" on public.eventos;
create policy "eventos_select" on public.eventos
  for select using (
    is_admin()
    or escopo = 'igreja'
    or (
      escopo = 'criancas'
      and exists (
        select 1 from public.filhos f
        where f.responsavel_id = auth.uid()
          and extract(year from age(f.data_nascimento)) <= 12
      )
    )
    or (
      escopo = 'embaixadores_mensageiras'
      and (
        exists (
          select 1 from public.filhos f
          where f.responsavel_id = auth.uid()
            and extract(year from age(f.data_nascimento)) between 9 and 17
        )
        or exists (
          select 1 from public.profiles p
          join public.profile_ministerios pm on pm.profile_id = p.id and pm.ministerio = 'awake'
          where p.id = auth.uid()
            and p.data_nascimento is not null
            and extract(year from age(p.data_nascimento)) between 9 and 17
        )
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
      escopo in ('homens', 'mulheres', 'danca', 'diaconos', 'louvor', 'midia', 'multimidia', 'teatro', 'intercessao')
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

select 'eventos_select completo: idade de Embaixadores/Mensageiras + Intercessao.' as status;
