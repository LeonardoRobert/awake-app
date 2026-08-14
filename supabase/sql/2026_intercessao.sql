-- Adiciona o Ministerio de Intercessao como ministerio de servico (like
-- Coral/Danca/Diaconos/Louvor/Midia/Multimidia/Teatro), mas SEM escala de
-- servico -- por isso ele nao entra em ministeriosComEscalaServico (isso
-- e definido so no app, em lib/services/escala_servico_service.dart, nao
-- precisa de nada aqui no banco).
--
-- Repete a policy eventos_select inteira (mesma base do
-- RECUPERACAO_parte8_embaixadores_mensageiras.sql, que ja tinha a regra
-- de idade certa pra Embaixadores/Mensageiras -- NAO a do parte7, que
-- deixava esse escopo visivel pra todo mundo), so acrescentando
-- 'intercessao' na lista de ministerios "simples" (sem sub-filtro de
-- genero/categoria), do mesmo jeito que homens/mulheres/danca/diaconos/
-- louvor/midia/multimidia/teatro ja funcionam.
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
      -- Embaixadores e Mensageiras (9-17 anos): visivel pra quem tem
      -- filho nessa faixa, OU pra quem e adolescente do Awake nessa
      -- mesma faixa (idade propria).
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

-- is_lider_ministerio(escopo) -- usada em eventos_insert/update/delete
-- (RECUPERACAO_parte5) -- ja e generica por parametro (checa
-- profile_ministerios.ministerio = escopo e papel='lider', OR is_admin()
-- por dentro), entao 'intercessao' ja deveria funcionar sem mudanca
-- nenhuma aqui. Depois de rodar este arquivo, teste criar um evento de
-- Intercessao como lider desse ministerio -- se der erro de permissao,
-- me avisa que a funcao pode estar diferente do que o schema.sql (que
-- esta desatualizado) sugere.
--
-- Se profile_ministerios.ministerio ou eventos.escopo tiverem um CHECK
-- constraint limitando os valores aceitos (nao encontrei isso no
-- schema.sql, mas ele esta desatualizado), a insercao de 'intercessao'
-- vai falhar com erro de constraint -- nesse caso, descubra o nome da
-- constraint (Database > Tables > profile_ministerios/eventos > ver
-- constraints) e rode:
--   alter table public.profile_ministerios drop constraint <nome>;
--   alter table public.profile_ministerios add constraint <nome>
--     check (ministerio in (... lista atual ..., 'intercessao'));
-- (mesma ideia pra eventos.escopo, se existir).

select 'Ministerio de Intercessao liberado em eventos_select.' as status;
