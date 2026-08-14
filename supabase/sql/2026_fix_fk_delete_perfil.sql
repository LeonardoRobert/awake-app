-- Conserta o "Database error deleting user" do Dashboard (Authentication
-- > Users > Delete): hoje TODAS as FKs que apontam pra profiles(id) sao
-- NO ACTION, entao apagar um usuario trava assim que o Postgres tenta
-- seguir a cadeia auth.users -> profiles -> qualquer uma dessas 21
-- tabelas. Isso tambem e pre-requisito da feature "Apagar minha conta"
-- (self-service, hard delete) -- sem isso, TODO usuario que tentar
-- apagar a propria conta esbarra no mesmo erro.
--
-- So LEITURA de metadado (information_schema) + ALTER TABLE em cada FK
-- -- nao apaga NENHUMA linha, nao mexe em dado nenhum. So troca o que
-- acontece automaticamente no futuro quando um profile for apagado:
--
--   CASCADE (apaga a linha junto -- e dado que "pertence" a pessoa):
--     escala_servico_casais.profile_id_a / profile_id_b (colunas NOT
--       NULL -- nao da pra so limpar, a linha toda vira invalida)
--     filhos.responsavel_id (NOT NULL)
--     presencas_eventos.user_id (NOT NULL)
--     profile_ministerios.profile_id (NOT NULL)
--     pedidos_oracao.profile_id, testemunhos.profile_id,
--       transacoes_bancarias.profile_id (conteudo pessoal)
--
--   SET NULL (mantem a linha, so limpa quem fez -- registro nao e
--   "dessa pessoa", e de outra coisa que ela so criou/mexeu):
--     contribuicoes.profile_id e .lancado_por (fica o lancamento
--       financeiro pra prestacao de contas, so anonimiza)
--     checkins.feito_por, eventos.criado_por, escalas.criado_por,
--       escalas_servico.criado_por, escala_servico_casais.criado_por,
--       escala_servico_posicoes.profile_id / profile_id_2,
--       video_materiais.criado_por, outdoors.criado_por,
--       visitantes_primeira_vez.registrado_por
--
--   profiles.id -> auth.users(id): tambem precisa estar em CASCADE,
--   senao apagar o auth.users nem comeca a cadeia.
do $$
declare
  regra record;
  nome_constraint text;
begin
  for regra in
    select * from (values
      ('profiles', 'id', 'cascade'),
      ('presencas_eventos', 'user_id', 'cascade'),
      ('presencas_eventos', 'feito_por', 'set null'),
      ('escalas', 'criado_por', 'set null'),
      ('video_materiais', 'criado_por', 'set null'),
      ('eventos', 'criado_por', 'set null'),
      ('contribuicoes', 'profile_id', 'set null'),
      ('contribuicoes', 'lancado_por', 'set null'),
      ('escala_servico_casais', 'profile_id_a', 'cascade'),
      ('escala_servico_casais', 'profile_id_b', 'cascade'),
      ('escala_servico_casais', 'criado_por', 'set null'),
      ('escala_servico_posicoes', 'profile_id', 'set null'),
      ('escala_servico_posicoes', 'profile_id_2', 'set null'),
      ('escalas_servico', 'criado_por', 'set null'),
      ('filhos', 'responsavel_id', 'cascade'),
      ('pedidos_oracao', 'profile_id', 'cascade'),
      ('profile_ministerios', 'profile_id', 'cascade'),
      ('testemunhos', 'profile_id', 'cascade'),
      ('transacoes_bancarias', 'profile_id', 'cascade'),
      ('visitantes_primeira_vez', 'registrado_por', 'set null'),
      ('checkins', 'feito_por', 'set null'),
      ('outdoors', 'criado_por', 'set null')
    ) as t(tabela, coluna, acao)
  loop
    select tc.constraint_name into nome_constraint
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on tc.constraint_name = kcu.constraint_name
      and tc.table_schema = kcu.table_schema
    where tc.constraint_type = 'FOREIGN KEY'
      and tc.table_schema = 'public'
      and tc.table_name = regra.tabela
      and kcu.column_name = regra.coluna;

    if nome_constraint is null then
      raise notice 'Constraint nao encontrada: %.% -- pulando (confirme manualmente)', regra.tabela, regra.coluna;
    else
      execute format('alter table public.%I drop constraint %I', regra.tabela, nome_constraint);
      execute format(
        'alter table public.%I add constraint %I foreign key (%I) references %s(id) on delete %s',
        regra.tabela,
        nome_constraint,
        regra.coluna,
        case when regra.tabela = 'profiles' then 'auth.users' else 'public.profiles' end,
        regra.acao
      );
      raise notice 'OK: %.% -> on delete %', regra.tabela, regra.coluna, regra.acao;
    end if;
  end loop;
end $$;

select 'FKs de profiles/auth.users ajustadas -- confira os NOTICE acima pra ver se alguma ficou de fora.' as status;
