-- processar_lembretes() (rodada a cada 15 min via pg_cron) estava
-- quebrando TODA VEZ, ha bastante tempo, ao tentar ler
-- inscricoes.lembrete_24h_enviado -- essa coluna nunca existiu nessa
-- tabela (so' existe em escalas_servico). Como a funcao nao trata
-- erro, a excecao desfazia (rollback) TUDO que ja tinha sido feito
-- naquela mesma chamada -- por isso NENHUM lembrete saia (nem de
-- evento, nem de escala de servico, nem de escala Awake).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

alter table public.inscricoes
  add column if not exists lembrete_24h_enviado boolean not null default false,
  add column if not exists lembrete_3h_enviado boolean not null default false;

select 'inscricoes ganhou lembrete_24h_enviado/lembrete_3h_enviado.' as status;
