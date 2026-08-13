-- Robo de teste: esconde qualquer linha originada por conta de teste
-- de QUALQUER usuario real (inclusive admin) -- em listas, dashboards,
-- Caixa de Entrada, site publico, etc.
--
-- TECNICA: policy RESTRITIVA (AS RESTRICTIVE). Policies normais
-- (permissivas) se combinam com OU; restritivas se combinam com E por
-- cima do resultado das permissivas. Isso deixa a gente "amarrar" essa
-- regra por cima de policies ja existentes (a de eventos, por exemplo,
-- e enorme) SEM precisar reescrever nenhuma delas.
--
-- Regra em todas: esconde se a origem da linha (quem criou/e dono) for
-- conta de teste -- EXCETO se quem esta olhando tambem for conta de
-- teste (assim o proprio robo consegue ler o que ele mesmo criou, pra
-- se auto-verificar).

create or replace function public.is_conta_teste()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select eh_conta_teste from public.profiles where id = auth.uid()), false);
$$;

-- Mesma ideia de is_conta_teste(), mas pra checar um profile_id
-- QUALQUER (nao so quem esta logado) -- usada pelas policies abaixo
-- que precisam saber se o DONO de uma linha (nao o viewer) e conta de
-- teste. PRECISA ser SECURITY DEFINER: sem isso, a subconsulta em
-- profiles fica sujeita a policy_ocultar_teste da propria profiles,
-- que ja esconde a linha da conta de teste -- criando um paradoxo
-- (a subconsulta nao acha a linha, cai no coalesce(null,false)=false,
-- e a policy conclui erradamente que NAO e conta de teste).
create or replace function public.eh_conta_teste(p_profile_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select eh_conta_teste from public.profiles where id = p_profile_id), false);
$$;

-- ===== profiles =====
-- Perfis de conta de teste (ex: "[TESTE] Membro") somem de qualquer
-- busca/lista pra usuario real -- exceto a propria pessoa ver o
-- proprio perfil (auth.uid() = id), que precisa continuar funcionando
-- pro login/uso normal do app.
drop policy if exists "profiles_ocultar_teste" on public.profiles;
create policy "profiles_ocultar_teste" on public.profiles
  as restrictive for select
  using (
    not coalesce(eh_conta_teste, false)
    or auth.uid() = id
    or is_conta_teste()
  );

-- ===== profile_ministerios =====
-- Sem isso, os dashboards de lider/admin que construimos ficariam com
-- numero de membros/idade media/etc contaminados pelas contas de
-- teste.
drop policy if exists "profile_ministerios_ocultar_teste" on public.profile_ministerios;
create policy "profile_ministerios_ocultar_teste" on public.profile_ministerios
  as restrictive for select
  using (
    not public.eh_conta_teste(profile_ministerios.profile_id)
    or is_conta_teste()
  );

-- ===== contribuicoes =====
drop policy if exists "contribuicoes_ocultar_teste" on public.contribuicoes;
create policy "contribuicoes_ocultar_teste" on public.contribuicoes
  as restrictive for select
  using (
    not public.eh_conta_teste(contribuicoes.profile_id)
    or is_conta_teste()
  );

-- ===== escalas_servico =====
drop policy if exists "escalas_servico_ocultar_teste" on public.escalas_servico;
create policy "escalas_servico_ocultar_teste" on public.escalas_servico
  as restrictive for select
  using (
    not public.eh_conta_teste(escalas_servico.criado_por)
    or is_conta_teste()
  );

-- ===== escala_servico_posicoes =====
-- Nao tem coluna de "quem criou" direto -- usa o criado_por da escala
-- (escalas_servico) a qual a posicao pertence.
drop policy if exists "escala_servico_posicoes_ocultar_teste" on public.escala_servico_posicoes;
create policy "escala_servico_posicoes_ocultar_teste" on public.escala_servico_posicoes
  as restrictive for select
  using (
    not exists (
      select 1 from public.escalas_servico es
      where es.id = escala_servico_posicoes.escala_id
        and public.eh_conta_teste(es.criado_por)
    )
    or is_conta_teste()
  );

-- ===== eventos =====
-- Essa e a mais importante: protege tanto a leitura de usuario logado
-- (eventos_select) quanto a leitura publica anonima (eventos_select_
-- publico, usada pelo site.html) -- restritiva se aplica em cima das
-- duas de uma vez.
drop policy if exists "eventos_ocultar_teste" on public.eventos;
create policy "eventos_ocultar_teste" on public.eventos
  as restrictive for select
  using (
    not public.eh_conta_teste(eventos.criado_por)
    or is_conta_teste()
  );

-- ===== pedidos_oracao =====
drop policy if exists "pedidos_oracao_ocultar_teste" on public.pedidos_oracao;
create policy "pedidos_oracao_ocultar_teste" on public.pedidos_oracao
  as restrictive for select
  using (
    not public.eh_conta_teste(pedidos_oracao.profile_id)
    or is_conta_teste()
  );

-- ===== testemunhos =====
drop policy if exists "testemunhos_ocultar_teste" on public.testemunhos;
create policy "testemunhos_ocultar_teste" on public.testemunhos
  as restrictive for select
  using (
    not public.eh_conta_teste(testemunhos.profile_id)
    or is_conta_teste()
  );

-- ===== visitantes_primeira_vez =====
drop policy if exists "visitantes_pv_ocultar_teste" on public.visitantes_primeira_vez;
create policy "visitantes_pv_ocultar_teste" on public.visitantes_primeira_vez
  as restrictive for select
  using (
    not public.eh_conta_teste(visitantes_primeira_vez.registrado_por)
    or is_conta_teste()
  );
